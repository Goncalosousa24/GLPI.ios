# 📱 GLPI Mobile Client (iOS)

![Swift](https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=apple&logoColor=white)
![Xcode](https://img.shields.io/badge/Xcode-1575F9?style=for-the-badge&logo=xcode&logoColor=white)

A fully native iOS application designed to seamlessly integrate with the **GLPI (IT Service Management)** backend. Built entirely with Swift and SwiftUI, this app empowers IT professionals and regular users to manage support tickets, track hardware inventory, and organize tasks directly from their iPhones.

## ✨ Key Features & Modules

The application is divided into several powerful modules, offering a comprehensive mobile experience for GLPI:

* 🏠 **Interactive Dashboard:** Get an instant overview of your IT landscape with real-time statistics powered by **Swift Charts**. Track tickets by status and monitor system activities at a glance.
* 🎫 **Full Ticket Lifecycle:** Complete ITIL workflow support. Create, view, update, resolve, and reply to support tickets on the go. Attach images directly from the iOS gallery using native `PhotosUI`.
* 📦 **Smart Inventory (OCR) & Reservations:** Browse assigned IT equipment (computers, network gear). Features a built-in **Smart Scanner** leveraging the device camera (`AVFoundation` & `Vision`) for Optical Character Recognition (OCR), instantly extracting serial numbers to identify and securely reserve devices.
* 🧩 **iOS Home Screen Widgets:** Deep integration with the Apple ecosystem using `WidgetKit`, allowing users to see critical ticket updates and information directly on their iPhone home screen.
* 👤 **Profile & Custom UX:** Personal overview displaying your assigned devices and account details. Features a custom Design System with dynamic adaptation for **Dark/Light Mode** and seamless transitions.
* 🔌 **GLPI REST API Integration:** Communicates entirely via the official GLPI REST API using a 100% custom `URLSession` network layer, ensuring secure and fast data synchronization without heavy third-party middleware.
* ✈️ **Resilient Offline Mode:** Built-in network failure interception. The app falls back to a robust mock-data architecture when offline, guaranteeing a fluid User Experience (UX) without crashes.

## 📸 Screenshots

| Dashboard | Inventory | Agenda | Profile |
|:---:|:---:|:---:|:---:|
| <img width="220" alt="1" src="https://github.com/user-attachments/assets/5fe66ae8-b70b-47bf-9e5e-f466b09782b8" /> | <img width="220" alt="2" src="https://github.com/user-attachments/assets/cd0cef24-437e-4f2e-96ba-782abd5ac8ef" /> | <img width="220" alt="3" src="https://github.com/user-attachments/assets/3caae156-25bc-4d51-9952-79e54042f2ec" /> | <img width="220" alt="4" src="https://github.com/user-attachments/assets/8c747d67-fc6d-4c7e-8c23-de4a29d75845" /> |

> ℹ️ **Note:** The screenshots above were captured using the application in **Offline Mode**. All visible data (names, tickets, hardware) is dynamically generated mock data designed purely for demonstration and portfolio purposes without requiring a real GLPI server connection.

## 🛠️ Tech Stack & Architecture

This project was built with modern Apple iOS development standards:

* **Language:** [Swift](https://www.swift.org/)
* **Architecture:** MVVM (Model-View-ViewModel)
* **UI Framework:** SwiftUI
* **Reactive Programming:** Combine (`@StateObject`, `@Published`)
* **Networking:** Native `URLSession` (No Alamofire required)
* **Hardware & ML APIs:** `AVFoundation`, `Vision` (OCR / Scanner), `PhotosUI`
* **Ecosystem Integration:** `WidgetKit` (Widgets) and `UserNotifications`
* **Local Storage:** `UserDefaults` and `@AppStorage`

## 🚀 How to Run the Project

1. **Clone the repository:**
   `git clone https://github.com/Goncalosousa24/GLPI.ios.git`

2. **GLPI API Configuration:**
   * Due to security reasons, the real production `App-Token` and Server URLs have been redacted from this public repository.
   * To connect to your real server, open `PreferenceManager.swift` and replace the placeholder strings with your actual GLPI App-Token and Session-Token. 
   * Navigate to `LoginView.swift` to update the Base URL.

3. **Build & Run:**
   * Open the `GLPI.IOS.xcodeproj` file in **Xcode**.
   * Select a Simulator (e.g., iPhone 15 Pro) and hit `Cmd + R` to build and run the project.

## 👨💻 Author

**Gonçalo Sousa**
* GitHub: [@Goncalosousa24](https://github.com/Goncalosousa24)
