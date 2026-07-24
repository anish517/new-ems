"""
Custom DRF authentication backend that reads the JWT access token
from the `token` URL query parameter.

This allows browser-based downloads to authenticate without setting
custom request headers (which `url_launcher` / browser cannot do).
"""
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError


class QueryParamJWTAuthentication(JWTAuthentication):
    """
    Extends JWTAuthentication to also accept the token via ?token= in the URL.
    Falls back to the standard Authorization header if the param is absent.
    """

    def get_header(self, request):
        # First try standard header
        header = super().get_header(request)
        if header:
            return header

        # Fall back to query param
        token = request.query_params.get('token') or request.GET.get('token')
        if token:
            # Encode as bytes so the parent raw_token extractor can process it
            return b'Bearer ' + token.encode('utf-8')

        return None
