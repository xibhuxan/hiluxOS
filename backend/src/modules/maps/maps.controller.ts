import { Controller, Get, Query } from '@nestjs/common';
import { MapsService } from './maps.service';
import { GeocodeQueryDto, ReverseQueryDto, RouteQueryDto } from './dto/maps.dto';

@Controller('maps')
export class MapsController {
  constructor(private readonly maps: MapsService) {}

  @Get('geocode')
  geocode(@Query() query: GeocodeQueryDto) {
    return this.maps.geocode(query.q);
  }

  @Get('reverse')
  reverse(@Query() query: ReverseQueryDto) {
    return this.maps.reverse(parseFloat(query.lat), parseFloat(query.lon));
  }

  @Get('route')
  route(@Query() query: RouteQueryDto) {
    const [fromLat, fromLon] = query.from.split(',').map(Number);
    const [toLat, toLon] = query.to.split(',').map(Number);
    return this.maps.route(fromLat, fromLon, toLat, toLon);
  }
}
