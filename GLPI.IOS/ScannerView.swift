import SwiftUI
import AVFoundation
import PhotosUI
import Vision

// Limpeza inteligente de prefixos comuns de Número de Série (ex: "SN:", "S/N:", "SN...123", "Serial No:", "SN\123")
func cleanSerialFromText(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Expressão regular case-insensitive para detetar "sn", "s/n", "serial", "serial no", "serial number"
    // seguidos de qualquer combinação de pontuação (incluindo barras \, /, colunas :, traços -, pontos .) e/ou espaços.
    let pattern = "^(?i)(serial\\s*(?:number|no)?|s/n|sn)[\\s\\p{Punct}]+"
    
    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        if let match = regex.firstMatch(in: trimmed, options: [], range: range) {
            let matchRange = match.range
            let startIndex = trimmed.index(trimmed.startIndex, offsetBy: matchRange.length)
            let result = trimmed[startIndex...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !result.isEmpty {
                return result
            }
        }
    }
    
    return trimmed
}

struct ScannerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isShowingPicker = false
    @State private var capturedImage: UIImage?
    var onScan: ((String) -> Void)? = nil
    
    @State private var isFlashOn = false
    
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
            CameraPreview(onScan: { code in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onScan?(code)
                dismiss()
            })
            .ignoresSafeArea()
            #endif
            
            // Overlay Estilo iOS Nativo
            VStack {
                // Header (Flash e Fechar)
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: GlpiMetrics.universalBackIcon)
                            .font(.system(size: GlpiMetrics.universalBackIconSize, weight: GlpiMetrics.universalBackIconWeight))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 5)
                    
                    Spacer()
                    
                    Button(action: { toggleFlash() }) {
                        Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 5)
                .frame(height: GlpiMetrics.navAreaHeight - 5)
                .padding(.horizontal, 20)
                
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
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                scanBarcodesFromImage(image) { scannedCode in
                    if let code = scannedCode {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onScan?(cleanSerialFromText(code))
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        isFlashOn.toggle()
        device.torchMode = isFlashOn ? .on : .off
        device.unlockForConfiguration()
    }
    
    // Scanner Vision de imagem da Galeria (Código de Barras ou OCR Fallback)
    private func scanBarcodesFromImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNDetectBarcodesRequest { request, error in
            guard error == nil else {
                completion(nil)
                return
            }
            
            if let results = request.results as? [VNBarcodeObservation],
               let firstBarcode = results.first?.payloadStringValue {
                completion(firstBarcode)
            } else {
                // Tenta OCR se não encontrar nenhum código de barras na imagem
                let textRequest = VNRecognizeTextRequest { textRequest, textError in
                    guard let textResults = textRequest.results as? [VNRecognizedTextObservation] else {
                        completion(nil)
                        return
                    }
                    
                    // Extrai todas as linhas de texto detetadas na imagem
                    let candidates = textResults.compactMap { $0.topCandidates(1).first?.string }
                    
                    // 1. Prioridade máxima: Linha que contém termos de Serial Number ("sn", "s/n", "serial")
                    let keywords = ["sn", "s/n", "serial"]
                    for candidate in candidates {
                        let lowercased = candidate.lowercased()
                        for kw in keywords {
                            if lowercased.contains(kw) {
                                completion(candidate)
                                return
                            }
                        }
                    }
                    
                    // 2. Prioridade secundária: Ordenar linhas pelo critério de maior probabilidade de ser um código
                    // (tem números/dígitos e menos espaços, evitando cabeçalhos longos de texto)
                    let sortedCandidates = candidates.sorted { c1, c2 in
                        let c1HasDigits = c1.contains(where: { $0.isNumber })
                        let c2HasDigits = c2.contains(where: { $0.isNumber })
                        if c1HasDigits != c2HasDigits {
                            return c1HasDigits ? true : false
                        }
                        
                        let c1Spaces = c1.filter { $0 == " " }.count
                        let c2Spaces = c2.filter { $0 == " " }.count
                        return c1Spaces < c2Spaces
                    }
                    
                    if let bestCandidate = sortedCandidates.first {
                        completion(bestCandidate)
                    } else {
                        completion(nil)
                    }
                }
                textRequest.recognitionLevel = .accurate
                let textHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? textHandler.perform([textRequest])
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
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
    var onScan: (String) -> Void

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: CameraPreview
        var device: AVCaptureDevice?
        var initialZoomFactor: CGFloat = 1.0

        init(_ parent: CameraPreview) {
            self.parent = parent
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let device = device else { return }
            
            do {
                try device.lockForConfiguration()
                
                if gesture.state == .began {
                    initialZoomFactor = device.videoZoomFactor
                }
                
                let minZoom = device.minAvailableVideoZoomFactor
                let maxZoom = min(device.maxAvailableVideoZoomFactor, 8.0) // Limite de 8x para preservar qualidade
                
                let zoomFactor = initialZoomFactor * gesture.scale
                device.videoZoomFactor = max(minZoom, min(zoomFactor, maxZoom))
                
                device.unlockForConfiguration()
            } catch {
                print("Falha ao configurar o zoom do dispositivo: \(error)")
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               let scannedValue = metadataObject.stringValue {
                // Feedback tátil de sucesso
                DispatchQueue.main.async {
                    self.parent.onScan(cleanSerialFromText(scannedValue))
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.screenWidth, height: UIScreen.screenHeight))
        let session = AVCaptureSession()
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }
        
        context.coordinator.device = device
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            // Suporte completo a códigos de barras 1D e 2D comuns
            metadataOutput.metadataObjectTypes = [.qr, .code128, .code39, .code93, .ean13, .ean8, .upce, .dataMatrix, .pdf417]
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer)
        
        // Gesto de Pinch para Zoom
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)
        
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
