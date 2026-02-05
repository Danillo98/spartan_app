import requests
import json

SUPABASE_URL = 'https://waczgosbsrorcibwfayv.supabase.co'
SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndhY3pnb3Nic3JvcmNpYndmYXl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgzOTQzNTgsImV4cCI6MjA4Mzk3MDM1OH0.IkVIseJ0StG6XKmcEpvTVaqCYfSRwVmASOquNQIwz-w'

headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json"
}

def get_table_info(table_name):
    # O PostgREST não tem endpoint direto para metadata de tabela facilmente acessível via anon key
    # a menos que 'information_schema' esteja exposto (geralmente não está).
    # Mas podemos tentar dar um SELECT * com limit 1 para ver as chaves do JSON retornado.
    url = f"{SUPABASE_URL}/rest/v1/{table_name}?select=*&limit=1"
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            data = response.json()
            if data and len(data) > 0:
                print(f"\n--- Colunas detectadas em '{table_name}' (via registro existente) ---")
                print(list(data[0].keys()))
            else:
                print(f"\n--- Tabela '{table_name}' está vazia ou inacessível. Tentando OPTIONS... ---")
                # Tentar OPTIONS para ver OpenAPI spec (nem sempre funciona)
        else:
            print(f"Erro ao acessar {table_name}: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Erro na requisição: {e}")

get_table_info('pending_registrations')
get_table_info('email_verification_codes')
