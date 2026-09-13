class EmailDeliveryError(Exception):
    """Indicate that an email could not be submitted for delivery."""


class KeeboxKeyDecryptionError(Exception):
    """Indicate that an encrypted KBKey could not be safely recovered."""
