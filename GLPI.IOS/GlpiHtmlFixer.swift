import Foundation

struct GlpiHtmlFixer {
    static func clean(_ html: String?) -> String {
        guard let html = html, !html.isEmpty else {
            return "Sem descrição."
        }
        
        var text = html
        
        // PASSO 1 — Descodificar entidades numéricas mais frequentes
        for _ in 0..<3 {
            text = text
                .replacingOccurrences(of: "&#38;", with: "&")
                .replacingOccurrences(of: "&#60;", with: "<")
                .replacingOccurrences(of: "&#62;", with: ">")
                .replacingOccurrences(of: "&#34;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&#160;", with: " ")
                .replacingOccurrences(of: "&#59;", with: ";")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&apos;", with: "'")
                .replacingOccurrences(of: "&nbsp;", with: " ")
        }
        
        // PASSO 2 — Remover blocos <style>...</style> e <script>...</script>
        var cleaned = removeBlock(text, startTag: "<style", endTag: "</style>")
        cleaned = removeBlock(cleaned, startTag: "<script", endTag: "</script>")
        
        // PASSO 3 — Remover todas as tags HTML: <qualquercoisa>
        cleaned = cleaned.replacingOccurrences(of: "<[^>]{0,5000}>", with: "", options: .regularExpression)
        
        var result = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove email header blocks that appear at the start of the content
        // Pattern: "De: ...\nEnviado: ...\nPara: ...\nAssunto: ..."
        if let regex = try? NSRegularExpression(pattern: "(?i)(^|\\n)(de|from)\\s*:.*?(\\n|$)(enviado|sent)\\s*:.*?(\\n|$)(para|to)\\s*:.*?(\\n|$)(assunto|subject)\\s*:.*?(\\n|$)", options: [.dotMatchesLineSeparators]) {
            let range = NSRange(location: 0, length: result.utf16.count)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "\n")
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Institutional signature block
        let lineAnchoredPatterns = [
            "(?im)^\\s*(município de vila verde|municipio de vila verde)\\s*$",
            "(?im)^\\s*(câmara municipal|camara municipal)\\s*(de vila verde)?\\s*$",
            "(?im)^\\s*telf\\s*:",
            "(?im)^\\s*www\\.cm-",
            "(?im)^\\s*site\\s*:\\s*www\\."
        ]
        for pattern in lineAnchoredPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: result.utf16.count)
                if let firstMatch = regex.firstMatch(in: result, options: [], range: range) {
                    let nsrange = firstMatch.range
                    if nsrange.location > 0 {
                        result = String(result.prefix(nsrange.location))
                    }
                }
            }
        }
        
        // Simple substring truncation for clearly unique footer strings
        let truncateKeywords = [
            "aviso de confidencialidade", "esta mensagem e quaisquer anexos",
            "confidencialidade:", "*****", "-----",
            "de: ", "enviado: ", "para: ", "assunto: ",
            "from: ", "sent: ", "to: ", "subject: ",
            "this email alert was generated",
            "do not reply to this email",
            "do not reply",
            "this is an automated",
            "you are receiving this email",
            "esta é uma mensagem automática",
            "não responda a este email"
        ]
        
        for kw in truncateKeywords {
            let lower = result.lowercased()
            if let range = lower.range(of: kw) {
                let distance = lower.distance(from: lower.startIndex, to: range.lowerBound)
                if distance > 0 {
                    result = String(result.prefix(distance))
                }
            }
        }
        
        // PASSO 5 — Normalizar espaços/newlines
        if let spacesRegex = try? NSRegularExpression(pattern: "[ \t]+", options: []) {
            let range = NSRange(location: 0, length: result.utf16.count)
            result = spacesRegex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: " ")
        }
        if let newlinesRegex = try? NSRegularExpression(pattern: "\n{3,}", options: []) {
            let range = NSRange(location: 0, length: result.utf16.count)
            result = newlinesRegex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "\n\n")
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func removeBlock(_ input: String, startTag: String, endTag: String) -> String {
        var text = input
        while true {
            let lower = text.lowercased()
            guard let sRange = lower.range(of: startTag.lowercased()) else { break }
            let s = lower.distance(from: lower.startIndex, to: sRange.lowerBound)
            
            if let eRange = lower.range(of: endTag.lowercased(), range: sRange.upperBound..<lower.endIndex) {
                let e = lower.distance(from: lower.startIndex, to: eRange.lowerBound)
                let endOffset = lower.distance(from: lower.startIndex, to: eRange.upperBound)
                
                let prefix = String(text.prefix(s))
                let suffix = String(text.suffix(text.count - endOffset))
                text = prefix + suffix
            } else {
                text = String(text.prefix(s))
            }
        }
        return text
    }
    
    /// Descodifica apenas as entidades HTML de uma string sem remover tags
    static func unescapeHtml(_ text: String) -> String {
        var str = text
        for _ in 0..<3 {
            str = str
                .replacingOccurrences(of: "&#38;", with: "&")
                .replacingOccurrences(of: "&#60;", with: "<")
                .replacingOccurrences(of: "&#62;", with: ">")
                .replacingOccurrences(of: "&#34;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&#160;", with: " ")
                .replacingOccurrences(of: "&#59;", with: ";")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&apos;", with: "'")
                .replacingOccurrences(of: "&nbsp;", with: " ")
        }
        return str
    }
}
