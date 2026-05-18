const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
const PORT = 3001;

// Enable CORS for all origins
app.use(cors());
app.use(express.json());

// Simulated places data for testing
const mockPlaces = [
  {
    place_id: '1',
    description: 'Jirón Las Coralinas 870, La Molina, Lima',
    structured_formatting: {
      main_text: 'Jirón Las Coralinas 870',
      secondary_text: 'La Molina, Lima'
    }
  },
  {
    place_id: '2',
    description: 'Jirón Las Palmeras 123, San Isidro, Lima',
    structured_formatting: {
      main_text: 'Jirón Las Palmeras 123',
      secondary_text: 'San Isidro, Lima'
    }
  },
  {
    place_id: '3',
    description: 'Avenida Javier Prado Este 456, San Borja, Lima',
    structured_formatting: {
      main_text: 'Avenida Javier Prado Este 456',
      secondary_text: 'San Borja, Lima'
    }
  }
];

// Places autocomplete endpoint
app.get('/api/places/autocomplete', (req, res) => {
  const { input } = req.query;
  console.log('Received autocomplete request for:', input);
  
  // Filter mock places based on input
  const filteredPlaces = input && input.length > 2
    ? mockPlaces.filter(place => 
        place.description.toLowerCase().includes(input.toLowerCase())
      )
    : [];
  
  res.json({
    predictions: filteredPlaces,
    status: 'OK'
  });
});

// Place details endpoint
app.get('/api/places/details/:placeId', (req, res) => {
  const { placeId } = req.params;
  console.log('Received details request for place:', placeId);
  
  // Return mock details
  res.json({
    result: {
      place_id: placeId,
      name: 'Mock Location',
      formatted_address: 'Jirón Las Coralinas 870, La Molina, Lima, Peru',
      geometry: {
        location: {
          lat: -12.0851,
          lng: -76.9770
        }
      }
    },
    status: 'OK'
  });
});

// Geocoding endpoint
app.get('/api/geocode', (req, res) => {
  const { lat, lng } = req.query;
  console.log('Received geocode request for:', lat, lng);
  
  res.json({
    results: [{
      formatted_address: 'Jirón Las Coralinas 870, La Molina, Lima, Peru',
      geometry: {
        location: {
          lat: parseFloat(lat) || -12.0851,
          lng: parseFloat(lng) || -76.9770
        }
      },
      place_id: 'mock_place_id'
    }],
    status: 'OK'
  });
});

app.listen(PORT, () => {
  console.log(`Mock proxy server running on http://localhost:${PORT}`);
  console.log('Available endpoints:');
  console.log('  - GET /api/places/autocomplete?input=<search_query>');
  console.log('  - GET /api/places/details/:placeId');
  console.log('  - GET /api/geocode?lat=<latitude>&lng=<longitude>');
});