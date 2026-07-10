function isValidTitle(title) {
  return typeof title === 'string' && title.trim().length > 0 && title.trim().length <= 255;
}

module.exports = { isValidTitle };
