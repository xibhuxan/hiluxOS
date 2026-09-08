import { Controller, Get, Query } from '@nestjs/common';
import { WeatherService } from './weather.service';
import { WeatherQueryDto } from './dto/weather.dto';

@Controller('weather')
export class WeatherController {
  constructor(private readonly weather: WeatherService) {}

  @Get()
  current(@Query() query: WeatherQueryDto) {
    return this.weather.getCurrent(query.lat, query.lon, query.city);
  }

  @Get('forecast')
  forecast(@Query() query: WeatherQueryDto) {
    return this.weather.getForecast(query.lat, query.lon, query.city);
  }
}
