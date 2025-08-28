// Test setup and configuration
import { beforeAll, afterAll, beforeEach, afterEach } from '@jest/globals';
import * as admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

// Initialize Firebase Admin for testing
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'oasis-taxi-test',
    credential: admin.credential.applicationDefault(),
  });
}

export const db = getFirestore();
export const auth = getAuth();

// Test data cleanup
export const cleanupTestData = async () => {
  try {
    // Clean up test collections
    const collections = [
      'test_users',
      'test_rides', 
      'test_payments',
      'test_notifications',
      'test_chat_messages',
      'test_ratings'
    ];

    for (const collectionName of collections) {
      const snapshot = await db.collection(collectionName).get();
      const batch = db.batch();
      
      snapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      
      if (!snapshot.empty) {
        await batch.commit();
      }
    }
  } catch (error) {
    console.error('Error cleaning up test data:', error);
  }
};

// Create test user
export const createTestUser = async (userData: any) => {
  try {
    const userRecord = await auth.createUser({
      uid: userData.uid,
      email: userData.email,
      password: 'testpassword123',
      displayName: userData.displayName,
      phoneNumber: userData.phoneNumber,
    });

    await db.collection('test_users').doc(userRecord.uid).set({
      ...userData,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    return userRecord;
  } catch (error) {
    console.error('Error creating test user:', error);
    throw error;
  }
};

// Delete test user
export const deleteTestUser = async (uid: string) => {
  try {
    await auth.deleteUser(uid);
    await db.collection('test_users').doc(uid).delete();
  } catch (error) {
    console.error('Error deleting test user:', error);
  }
};

// Generate test JWT token
export const generateTestToken = async (uid: string) => {
  try {
    return await auth.createCustomToken(uid);
  } catch (error) {
    console.error('Error generating test token:', error);
    throw error;
  }
};

// Test data generators
export const generateTestRide = (overrides: any = {}) => ({
  id: `test_ride_${Date.now()}`,
  passengerId: 'test_passenger_1',
  driverId: null,
  status: 'searching',
  pickup: {
    lat: -34.6037,
    lng: -58.3816,
    address: 'Test Pickup Address',
  },
  destination: {
    lat: -34.6118,
    lng: -58.3960,
    address: 'Test Destination Address',
  },
  estimatedFare: 1500,
  estimatedDuration: 15,
  estimatedDistance: 5.2,
  createdAt: new Date(),
  updatedAt: new Date(),
  ...overrides,
});

export const generateTestPayment = (overrides: any = {}) => ({
  id: `test_payment_${Date.now()}`,
  userId: 'test_user_1',
  rideId: 'test_ride_1',
  amount: 1500,
  currency: 'ARS',
  method: 'card',
  status: 'pending',
  gatewayResponse: null,
  createdAt: new Date(),
  updatedAt: new Date(),
  ...overrides,
});

export const generateTestNotification = (overrides: any = {}) => ({
  id: `test_notification_${Date.now()}`,
  userId: 'test_user_1',
  type: 'ride_assigned',
  title: 'Test Notification',
  body: 'This is a test notification',
  data: {},
  read: false,
  createdAt: new Date(),
  ...overrides,
});

// Mock HTTP request helper
export const mockRequest = (overrides: any = {}) => ({
  method: 'GET',
  url: '/test',
  headers: {},
  body: {},
  query: {},
  params: {},
  userId: null,
  ...overrides,
});

// Mock HTTP response helper
export const mockResponse = () => {
  const res: any = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  res.send = jest.fn().mockReturnValue(res);
  res.cookie = jest.fn().mockReturnValue(res);
  res.clearCookie = jest.fn().mockReturnValue(res);
  return res;
};

// Setup and teardown hooks
beforeAll(async () => {
  console.log('Setting up test environment...');
  await cleanupTestData();
});

afterAll(async () => {
  console.log('Cleaning up test environment...');
  await cleanupTestData();
});

beforeEach(async () => {
  // Setup for each test
});

afterEach(async () => {
  // Cleanup after each test
});

// Error matchers
export const expectValidationError = (error: any, field?: string) => {
  expect(error).toBeDefined();
  expect(error.statusCode).toBe(400);
  expect(error.code).toBe('VALIDATION_ERROR');
  if (field) {
    expect(error.message).toContain(field);
  }
};

export const expectNotFoundError = (error: any) => {
  expect(error).toBeDefined();
  expect(error.statusCode).toBe(404);
};

export const expectUnauthorizedError = (error: any) => {
  expect(error).toBeDefined();
  expect(error.statusCode).toBe(401);
  expect(error.code).toBe('UNAUTHORIZED');
};

export const expectForbiddenError = (error: any) => {
  expect(error).toBeDefined();
  expect(error.statusCode).toBe(403);
};

// Test utilities
export const wait = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

export const generateRandomString = (length: number = 10) => {
  return Math.random().toString(36).substring(2, length + 2);
};

export const generateRandomNumber = (min: number = 0, max: number = 1000) => {
  return Math.floor(Math.random() * (max - min + 1)) + min;
};

export const generateRandomLocation = () => ({
  lat: -34.6037 + (Math.random() - 0.5) * 0.1,
  lng: -58.3816 + (Math.random() - 0.5) * 0.1,
});

// Assert helpers
export const assertApiResponse = (response: any, expectedStatus: number = 200) => {
  expect(response.success).toBe(expectedStatus < 400);
  expect(response.timestamp).toBeDefined();
  if (expectedStatus >= 400) {
    expect(response.error).toBeDefined();
  }
};

export const assertPaginationInfo = (pagination: any) => {
  expect(pagination).toBeDefined();
  expect(pagination.page).toBeGreaterThan(0);
  expect(pagination.limit).toBeGreaterThan(0);
  expect(pagination.total).toBeGreaterThanOrEqual(0);
  expect(pagination.totalPages).toBeGreaterThanOrEqual(0);
  expect(typeof pagination.hasNext).toBe('boolean');
  expect(typeof pagination.hasPrev).toBe('boolean');
};

// Mock external services
export const mockMercadoPago = {
  createPayment: jest.fn(),
  getPayment: jest.fn(),
  refundPayment: jest.fn(),
  cancelPayment: jest.fn(),
};

export const mockFirebaseMessaging = {
  send: jest.fn(),
  sendMulticast: jest.fn(),
  subscribeToTopic: jest.fn(),
  unsubscribeFromTopic: jest.fn(),
};

export const mockEmailService = {
  sendEmail: jest.fn(),
};

export const mockSMSService = {
  sendSMS: jest.fn(),
};