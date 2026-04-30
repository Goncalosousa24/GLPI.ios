import os

files = [
    "GLPI.IOS/DashboardView.swift",
    "GLPI.IOS/InventoryView.swift",
    "GLPI.IOS/AgendaView.swift",
    "GLPI.IOS/LoginView.swift",
    "GLPI.IOS/TicketCreateView.swift",
    "GLPI.IOS/TicketEditView.swift",
    "GLPI.IOS/GlpiDesign.swift"
]

for file_path in files:
    full_path = os.path.join("/Users/goncalosousa/AndroidStudioProjects/GLPImobile/ios", file_path)
    if not os.path.exists(full_path):
        print(f"File {file_path} not found.")
        continue
    
    with open(full_path, 'r') as f:
        content = f.read()
        open_braces = content.count('{')
        close_braces = content.count('}')
        if open_braces != close_braces:
            print(f"ERROR in {file_path}: {open_braces} open, {close_braces} closed.")
        else:
            print(f"OK: {file_path}")
