import { Body, Controller, Delete, Get, Param, Post, Query } from '@nestjs/common';
import { RadioService } from './radio.service';
import { SearchStationDto } from './dto/search-station.dto';
import { FavoriteStationDto } from './dto/favorite-station.dto';

@Controller('radio')
export class RadioController {
  constructor(private readonly radio: RadioService) {}

  @Get('stations/search')
  search(@Query() query: SearchStationDto) {
    return this.radio.search(query.q, query.country, query.tag);
  }

  @Get('stream/:id')
  resolveStream(@Param('id') id: string) {
    return this.radio.resolveStream(id);
  }

  @Get('favorites')
  favorites() {
    return this.radio.listFavorites();
  }

  @Post('favorites')
  addFavorite(@Body() dto: FavoriteStationDto) {
    return this.radio.addFavorite(dto);
  }

  @Delete('favorites')
  removeFavorite(@Query('url') url: string) {
    return this.radio.removeFavoriteByUrl(url);
  }

  @Post('history')
  recordHistory(@Body() dto: FavoriteStationDto) {
    return this.radio.recordHistory(dto);
  }

  @Get('history')
  history() {
    return this.radio.listHistory();
  }
}