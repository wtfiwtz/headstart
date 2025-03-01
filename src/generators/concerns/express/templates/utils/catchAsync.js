/**
 * Utility function to catch async errors in Express.js controllers
 * Eliminates the need for try/catch blocks in controller functions
 * 
 * @param {Function} fn - Async controller function
 * @returns {Function} - Express middleware function that catches errors
 */
module.exports = fn => {
  return (req, res, next) => {
    fn(req, res, next).catch(next);
  };
}; 