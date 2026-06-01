const url = "https://avypyaxthvgaybplnwxu.supabase.co/rest/v1/unidades?select=id,blocos(nome_ou_numero),apartamentos(numero),unidade_perfil(perfil(id,nome_completo))&limit=1";

fetch(url, {
  headers: {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2eXB5YXh0aHZnYXlicGxud3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyMTk5NzQsImV4cCI6MjA4Nzc5NTk3NH0.ZJfCCRJjVlHAVs02j_Ix61Y9reoFy2qur0S1VTB3NWo",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2eXB5YXh0aHZnYXlicGxud3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyMTk5NzQsImV4cCI6MjA4Nzc5NTk3NH0.ZJfCCRJjVlHAVs02j_Ix61Y9reoFy2qur0S1VTB3NWo"
  }
}).then(res => res.json()).then(data => console.log(JSON.stringify(data, null, 2)));
