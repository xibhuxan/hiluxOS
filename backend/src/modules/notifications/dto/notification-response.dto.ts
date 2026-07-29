export class NotificationResponseDto {
  id!: string;
  type!: string;
  title!: string;
  message?: string | null;
  action?: Record<string, unknown> | null;
  read!: boolean;
  createdAt!: string;
}
