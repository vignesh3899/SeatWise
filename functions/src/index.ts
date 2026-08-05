import * as admin from 'firebase-admin';
import {defineSecret} from 'firebase-functions/params';
import {logger} from 'firebase-functions/v2';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

import {handleRecommend} from './controllers/recommendationController';

admin.initializeApp();

// API keys are stored as Firebase secrets (never in source). For local
// emulation they are read from functions/.env via process.env as a fallback.
const openRouteApiKey = defineSecret('OPEN_ROUTE_API_KEY');
const openWeatherApiKey = defineSecret('OPEN_WEATHER_API_KEY');

/**
 * Callable that returns a seat recommendation for a given origin/destination.
 * Mirrors the on-device engine so the app can use either interchangeably.
 */
export const recommendSeat = onCall(
  {
    secrets: [openRouteApiKey, openWeatherApiKey],
    cors: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'You must be signed in to request a recommendation.'
      );
    }

    const keys = {
      ors: safeSecret(openRouteApiKey, 'OPEN_ROUTE_API_KEY'),
      weather: safeSecret(openWeatherApiKey, 'OPEN_WEATHER_API_KEY'),
    };

    try {
      return await handleRecommend(request.data, keys);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error('recommendSeat failed', error);
      throw new HttpsError('internal', 'Could not compute a recommendation.');
    }
  }
);

/** Reads a secret value, falling back to process.env for local emulation. */
function safeSecret(
  param: ReturnType<typeof defineSecret>,
  envName: string
): string {
  try {
    const value = param.value();
    if (value) return value;
  } catch {
    // Secret not bound (e.g. local emulator) — fall through to process.env.
  }
  return process.env[envName] ?? '';
}
