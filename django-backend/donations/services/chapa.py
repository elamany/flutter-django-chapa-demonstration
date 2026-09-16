from chapa import Chapa
from django.conf import settings
import httpx

class ChapaPaymentService:

    def __init__(self):
        self.client = Chapa(
            settings.CHAPA_SECRET_KEY
        )

    def initialize_payment(
        self,
        tx_ref,
        amount,
        email,
        first_name,
        last_name,
        return_url,
        customization={},
    ):
        response = self.client.initialize(
            tx_ref=tx_ref,
            amount=str(amount),
            currency='ETB',
            email=email,
            first_name=first_name,
            last_name=last_name,
            callback_url=return_url,
            customization=customization
        )

        return response
    
    def verify_payment(self, tx_ref):
        url = f'https://api.chapa.co/v1/transaction/verify/{tx_ref}'

        headers = {
            'Authorization': f'Bearer {settings.CHAPA_SECRET_KEY}',
        }

        response = httpx.get(
            url,
            headers=headers,
            timeout=10,
        )

        response.raise_for_status()

        return response.json()