const axios = require('axios');
const logger = require('../config/logger');

if (!process.env.API_BASE_URL) {
  console.warn('[apiClient] API_BASE_URL non défini. Configurez-le dans votre .env');
}

const api = axios.create({
  baseURL: process.env.API_BASE_URL || 'http://localhost:3000',
  timeout: Number(process.env.API_TIMEOUT || 8000),
});

async function request({ method, url, token, data, params }) {
  try {
    const response = await api.request({
      method,
      url,
      data,
      params,
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });
    return response.data;
  } catch (error) {
    if (error.response) {
      const { status, data: errorData } = error.response;
      logger.warn('[apiClient] Erreur API', { status, url, data: errorData });
      const message = errorData?.error || errorData?.message || 'Erreur API';
      const err = new Error(message);
      err.status = status;
      err.details = errorData;
      throw err;
    }
    logger.error('[apiClient] Erreur réseau', { url, message: error.message });
    throw error;
  }
}

module.exports = {
  get: (url, token, params) => request({ method: 'get', url, token, params }),
  post: (url, token, data) => request({ method: 'post', url, token, data }),
  delete: (url, token) => request({ method: 'delete', url, token }),
};

