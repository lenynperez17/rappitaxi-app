// Tipos básicos para API responses
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: ApiError;
  message?: string;
  timestamp?: string;
}

export interface ApiError {
  code: string;
  message: string;
  details?: any;
}

export interface LocationData {
  latitude: number;
  longitude: number;
  address?: string;
  city?: string;
  state?: string;
  country?: string;
}
// Tipos agregados para corregir errores de compilación
export interface PaginationInfo {
  page: number;
  limit: number; 
  total: number;
  totalPages: number;
}

export interface RequestUser {
  uid: string;
  email?: string;
  role?: string;
}
