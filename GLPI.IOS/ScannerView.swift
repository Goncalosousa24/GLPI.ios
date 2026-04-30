
import SwiftUI
import AVFoundation
import PhotosUI

struct ScannerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isShowingPicker = false
    @State private var capturedImage: UIImage?
    
    var body: some View {
        ZStack {
            // Fundo Preto para Câmera
            Color.black.ignoresSafeArea()
            
            // Câmera Preview
            #if targetEnvironment(simulator)
            ZStack {
                Color.black
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.2))
                    Text("Câmara Indisponível no Simulador")
                        .font(.amiko(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .ignoresSafeArea()
            #else
            CameraPreview()
                .ignoresSafeArea()
            #endif
            
            // Overlay Estilo iOS Nativo
            VStack {
                // Header (Flash e Fechar)
                HStack {
                    Button(action: { toggleFlash() }) {
                        Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
                
                // Footer (Galeria e Shutter)
                HStack {
                    // Galeria
                    Button(action: { isShowingPicker = true }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Shutter
                    Button(action: {
                        // Capturar
                    }) {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 75, height: 75)
                            .overlay(
                                Circle()
                                    .fill(Color.white)
                                    .padding(4)
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Espaço para manter o shutter centrado
                    Color.clear
                        .frame(width: 50, height: 50)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $isShowingPicker) {
            PhotoPicker(image: $capturedImage)
        }
    }
    
    @State private var isFlashOn = false
    
    private func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        isFlashOn.toggle()
        device.torchMode = isFlashOn ? .on : .off
        device.unlockForConfiguration()
    }
}

// MARK: - Scanner Visuals
struct ScannerCorners: View {
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    cornerShape().rotationEffect(.degrees(0))
                    Spacer()
                    cornerShape().rotationEffect(.degrees(90))
                }
                Spacer()
                HStack {
                    cornerShape().rotationEffect(.degrees(270))
                    Spacer()
                    cornerShape().rotationEffect(.degrees(180))
                }
            }
        }
        .foregroundColor(.blue)
    }
    
    func cornerShape() -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 40))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 40, y: 0))
        }
        .stroke(lineWidth: 4)
        .frame(width: 40, height: 40)
    }
}

// MARK: - Camera Preview Wrapper
struct CameraPreview: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.screenWidth, height: UIScreen.screenHeight))
        let session = AVCaptureSession()
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Photo Picker Wrapper
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.image = image as? UIImage
                }
            }
        }
    }
}
