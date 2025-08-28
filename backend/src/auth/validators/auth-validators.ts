/**
 * Email validation
 */
export const validateEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

/**
 * Password validation
 * Requirements: At least 8 characters, contains uppercase, lowercase, and numbers
 */
export const validatePassword = (password: string): boolean => {
  const minLength = 8;
  const hasUpperCase = /[A-Z]/.test(password);
  const hasLowerCase = /[a-z]/.test(password);
  const hasNumbers = /\d/.test(password);
  
  return password.length >= minLength && hasUpperCase && hasLowerCase && hasNumbers;
};

/**
 * Phone validation (supports international formats)
 */
export const validatePhone = (phone: string): boolean => {
  // Remove all non-digit characters
  const cleanPhone = phone.replace(/\D/g, '');
  
  // Check if it's between 10-15 digits (international phone number range)
  return cleanPhone.length >= 10 && cleanPhone.length <= 15;
};

/**
 * Name validation
 */
export const validateName = (name: string): boolean => {
  const nameRegex = /^[a-zA-ZÀ-ÿ\u00f1\u00d1\s]{2,}$/;
  return nameRegex.test(name.trim()) && name.trim().length >= 2;
};

/**
 * License number validation (basic format)
 */
export const validateLicenseNumber = (license: string): boolean => {
  // Remove spaces and convert to uppercase
  const cleanLicense = license.replace(/\s/g, '').toUpperCase();
  
  // Basic validation: alphanumeric, 6-20 characters
  const licenseRegex = /^[A-Z0-9]{6,20}$/;
  return licenseRegex.test(cleanLicense);
};

/**
 * Vehicle license plate validation
 */
export const validateLicensePlate = (plate: string): boolean => {
  // Remove spaces and convert to uppercase
  const cleanPlate = plate.replace(/\s/g, '').toUpperCase();
  
  // Basic validation: alphanumeric, 3-10 characters
  const plateRegex = /^[A-Z0-9]{3,10}$/;
  return plateRegex.test(cleanPlate);
};

/**
 * Bank account number validation (basic)
 */
export const validateBankAccountNumber = (accountNumber: string): boolean => {
  // Remove all non-digit characters
  const cleanAccount = accountNumber.replace(/\D/g, '');
  
  // Check if it's between 8-20 digits
  return cleanAccount.length >= 8 && cleanAccount.length <= 20;
};

/**
 * Validate role
 */
export const validateRole = (role: string): boolean => {
  const validRoles = ['passenger', 'driver', 'admin'];
  return validRoles.includes(role);
};

/**
 * Validate vehicle type
 */
export const validateVehicleType = (type: string): boolean => {
  const validTypes = ['standard', 'premium', 'xl'];
  return validTypes.includes(type);
};

/**
 * Validate payment method
 */
export const validatePaymentMethod = (method: string): boolean => {
  const validMethods = ['cash', 'credit_card', 'mercado_pago', 'wallet'];
  return validMethods.includes(method);
};

/**
 * Validate coordinates
 */
export const validateCoordinates = (lat: number, lng: number): boolean => {
  return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
};

/**
 * Validate rating (1-5 stars)
 */
export const validateRating = (rating: number): boolean => {
  return rating >= 1 && rating <= 5 && Number.isInteger(rating);
};

/**
 * Validate amount (positive number)
 */
export const validateAmount = (amount: number): boolean => {
  return typeof amount === 'number' && amount > 0 && isFinite(amount);
};

/**
 * Validate date (not in the past for future dates)
 */
export const validateFutureDate = (date: Date): boolean => {
  const now = new Date();
  return date > now;
};

/**
 * Validate date (not in the future for past dates)
 */
export const validatePastDate = (date: Date): boolean => {
  const now = new Date();
  return date <= now;
};

/**
 * Validate time slot format (HH:mm)
 */
export const validateTimeSlot = (time: string): boolean => {
  const timeRegex = /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/;
  return timeRegex.test(time);
};

/**
 * Comprehensive user registration validation
 */
export const validateUserRegistration = (userData: any): { isValid: boolean; errors: string[] } => {
  const errors: string[] = [];
  
  if (!userData.email || !validateEmail(userData.email)) {
    errors.push('Email inválido');
  }
  
  if (!userData.password || !validatePassword(userData.password)) {
    errors.push('Contraseña debe tener al menos 8 caracteres, incluir mayúsculas, minúsculas y números');
  }
  
  if (!userData.name || !validateName(userData.name)) {
    errors.push('Nombre debe tener al menos 2 caracteres y solo letras');
  }
  
  if (!userData.phone || !validatePhone(userData.phone)) {
    errors.push('Número de teléfono inválido');
  }
  
  if (userData.role && !validateRole(userData.role)) {
    errors.push('Rol inválido');
  }
  
  return {
    isValid: errors.length === 0,
    errors,
  };
};

/**
 * Driver document validation
 */
export const validateDriverDocument = (documentData: any): { isValid: boolean; errors: string[] } => {
  const errors: string[] = [];
  const validDocumentTypes = ['license', 'insurance', 'registration', 'identity', 'background_check'];
  
  if (!documentData.type || !validDocumentTypes.includes(documentData.type)) {
    errors.push('Tipo de documento inválido');
  }
  
  if (!documentData.url || typeof documentData.url !== 'string') {
    errors.push('URL del documento requerida');
  }
  
  if (documentData.expiryDate && !validateFutureDate(new Date(documentData.expiryDate))) {
    errors.push('Fecha de expiración debe ser futura');
  }
  
  return {
    isValid: errors.length === 0,
    errors,
  };
};

/**
 * Vehicle information validation
 */
export const validateVehicleInfo = (vehicleData: any): { isValid: boolean; errors: string[] } => {
  const errors: string[] = [];
  
  if (!vehicleData.make || typeof vehicleData.make !== 'string' || vehicleData.make.trim().length < 2) {
    errors.push('Marca del vehículo requerida');
  }
  
  if (!vehicleData.model || typeof vehicleData.model !== 'string' || vehicleData.model.trim().length < 2) {
    errors.push('Modelo del vehículo requerido');
  }
  
  const currentYear = new Date().getFullYear();
  if (!vehicleData.year || vehicleData.year < 1990 || vehicleData.year > currentYear + 1) {
    errors.push('Año del vehículo inválido');
  }
  
  if (!vehicleData.color || typeof vehicleData.color !== 'string' || vehicleData.color.trim().length < 2) {
    errors.push('Color del vehículo requerido');
  }
  
  if (!vehicleData.licensePlate || !validateLicensePlate(vehicleData.licensePlate)) {
    errors.push('Placa del vehículo inválida');
  }
  
  if (!vehicleData.type || !validateVehicleType(vehicleData.type)) {
    errors.push('Tipo de vehículo inválido');
  }
  
  if (!vehicleData.capacity || vehicleData.capacity < 1 || vehicleData.capacity > 8) {
    errors.push('Capacidad del vehículo debe ser entre 1 y 8');
  }
  
  return {
    isValid: errors.length === 0,
    errors,
  };
};