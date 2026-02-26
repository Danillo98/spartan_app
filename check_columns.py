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
    url = f"{SUPABASE_URL}/rest/v1/{table_name}?select=*&limit=1"
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            data = response.json()
            if data and len(data) > 0:
                print(f"\n--- Colunas detectadas em '{table_name}' ---")
                for key in sorted(data[0].keys()):
                    print(f"- {key}")
            else:
                print(f"\n--- Tabela '{table_name}' está vazia ou inacessível. ---")
        else:
            print(f"Erro ao acessar {table_name}: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Erro na requisição: {e}")

print("Verificando colunas da tabela users_alunos...")
get_table_info('users_alunos')
