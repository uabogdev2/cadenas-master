const levels = ['debug', 'info', 'warn', 'error'];

function format(level, message, meta) {
  const payload = {
    level,
    timestamp: new Date().toISOString(),
    message,
    ...(meta || {}),
  };
  return JSON.stringify(payload);
}

const logger = levels.reduce((acc, level) => {
  acc[level] = (message, meta) => {
    const serialized = format(level, message, meta);
    if (level === 'error') {
      console.error(serialized);
    } else if (level === 'warn') {
      console.warn(serialized);
    } else {
      console.log(serialized);
    }
  };
  return acc;
}, {});

module.exports = logger;

