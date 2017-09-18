import logging

_logger = None


def setup(logging_path, logging_level=logging.INFO):
	global _logger
	if _logger is None:
		logging.basicConfig(
			filename=logging_path,
			filemode='w',
			level=logging_level,
			format='%(asctime)s %(levelname)s - %(message)s'
		)
		_logger = logging.getLogger()
	else:
		f = logging.FileHandler(logging_path, 'w')
		f.setFormatter(logging.Formatter('%(asctime)s %(levelname)s - %(message)s'))
		for h in _logger.handlers:
			if isinstance(h, logging.FileHandler):
				_logger.removeHandler(h)
				_logger.addHandler(f)
				break
	_logger.info('Logger started')


def debug(msg, *args, **kwargs):
	if _logger is not None:
		_logger.debug(msg, *args, **kwargs)


def info(msg, *args, **kwargs):
	if _logger is not None:
		_logger.info(msg, *args, **kwargs)


def error(msg, *args, **kwargs):
	if _logger is not None:
		_logger.error(msg, *args, **kwargs)


def warning(msg, *args, **kwargs):
	if _logger is not None:
		_logger.warning(msg, *args, **kwargs)


def critical(msg, *args, **kwargs):
	if _logger is not None:
		_logger.critical(msg, *args, **kwargs)