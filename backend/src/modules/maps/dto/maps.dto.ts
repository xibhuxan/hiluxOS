import { IsNotEmpty, IsString, Matches, MinLength } from 'class-validator';

/** Query DTO for GET /api/maps/geocode?q=<texto> */
export class GeocodeQueryDto {
  @IsString()
  @MinLength(1)
  q!: string;
}

/** Query DTO for GET /api/maps/reverse?lat=&lon= */
export class ReverseQueryDto {
  @IsString()
  @Matches(/^-?\d+(\.\d+)?$/, { message: 'lat debe ser un número' })
  lat!: string;

  @IsString()
  @Matches(/^-?\d+(\.\d+)?$/, { message: 'lon debe ser un número' })
  lon!: string;
}

/** Query DTO for GET /api/maps/route?from=lat,lon&to=lat,lon */
export class RouteQueryDto {
  @IsString()
  @IsNotEmpty()
  @Matches(/^-?\d+(\.\d+)?,-?\d+(\.\d+)?$/, {
    message: 'from debe tener el formato "lat,lon"',
  })
  from!: string;

  @IsString()
  @IsNotEmpty()
  @Matches(/^-?\d+(\.\d+)?,-?\d+(\.\d+)?$/, {
    message: 'to debe tener el formato "lat,lon"',
  })
  to!: string;
}
