data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  max_subnet_count  = max(length(var.public_subnet_cidrs), length(var.private_subnet_cidrs))
  azs               = length(var.azs) > 0 ? var.azs : slice(data.aws_availability_zones.available.names, 0, local.max_subnet_count)
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = merge(var.tags, { Name = "vpc-${var.name}" })
}

resource "aws_internet_gateway" "igw" {
  count = length(var.public_subnet_cidrs) > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "igw-${var.name}" })
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = element(local.azs, count.index)
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(
    var.tags,
    var.public_subnet_tags,
    { Name = "snet-${var.name}-public-${element(local.azs, count.index)}" },
  )
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = element(local.azs, count.index)

  tags = merge(
    var.tags,
    var.private_subnet_tags,
    { Name = "snet-${var.name}-private-${element(local.azs, count.index)}" },
  )
}

resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"
  tags   = merge(var.tags, { Name = "eip-${var.name}-${count.index + 1}" })
}

resource "aws_nat_gateway" "ngw" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, { Name = "ngw-${var.name}-${count.index + 1}" })

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  count = length(var.public_subnet_cidrs) > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "rt-${var.name}-public" })
}

resource "aws_route" "public_internet" {
  count = length(var.public_subnet_cidrs) > 0 ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw[0].id
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "rt-${var.name}-private-${element(local.azs, count.index)}" })
}

resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? length(var.private_subnet_cidrs) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ngw[var.single_nat_gateway ? 0 : count.index].id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
