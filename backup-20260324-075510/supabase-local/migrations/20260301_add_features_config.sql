-- Migration: 1.5 Dynamic Home Configurations
-- Description: Adds features_config JSONB column to condominiums for UI customization.

ALTER TABLE public.condominiums 
ADD COLUMN IF NOT EXISTS features_config JSONB DEFAULT '{
  "resident_menu": [
    { "id": "occurrences", "icon": "warning", "label": "Ocorrências", "route": "/report-occurrence", "visible": true, "order": 1 },
    { "id": "chat", "icon": "chat", "label": "Chat Oficial", "route": "/official-chat", "visible": true, "order": 2 },
    { "id": "documents", "icon": "file_copy", "label": "Documentos", "route": "/document-center", "visible": true, "order": 3 },
    { "id": "bookings", "icon": "calendar_month", "label": "Reservas", "route": "/area-booking", "visible": true, "order": 4 },
    { "id": "parcels", "icon": "inventory_2", "label": "Minhas Encomendas", "route": "/parcel-dashboard", "visible": true, "order": 5 },
    { "id": "invites", "icon": "qr_code", "label": "Gerar Convite", "route": "/invitation-generator", "visible": true, "order": 6 }
  ],
  "admin_menu": [
    { "id": "approvals", "icon": "check_circle", "label": "Aprovações", "route": "/manager-approval", "visible": true, "order": 1 },
    { "id": "parcel_history", "icon": "history", "label": "Histórico Entregas", "route": "/parcel-history", "visible": true, "order": 2 }
  ],
  "porter_menu": [
    { "id": "parcel_reg", "icon": "add_box", "label": "Registrar Encomenda", "route": "/resident-search", "visible": true, "order": 1 },
    { "id": "pending_del", "icon": "local_shipping", "label": "Entregas Pendentes", "route": "/pending-deliveries", "visible": true, "order": 2 },
    { "id": "guest_checkin", "icon": "how_to_reg", "label": "Check-in Visitante", "route": "/guest-checkin", "visible": true, "order": 3 }
  ]
}'::jsonb;
