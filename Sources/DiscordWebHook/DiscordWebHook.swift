import Foundation

public class WebHookSender {
    public init(webhookURL: URL) {
        self.webhookURL = webhookURL
    }
    public var webhookURL: URL
    
    // Send's the Specified WebHook and returns both the Response Data and Response as (Data, URLResponse)
    @discardableResult
    public func send(_ content: WebHook) async throws -> (Data, URLResponse) {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        
        var payload = [String: Any]()
        
        if let content = content.content {
            if content.count > 2000 {
                print("WARNING: Message cannot be larger than 2000 characters, the Message will be clamped to the first 2000 characters")
            }
            payload["content"] = content.prefix(2000)
        }
        
        if let username = content.username {
            payload["username"] = username
        }
        
        if let tts = content.tts {
            payload["tts"] = tts
        }
        
        if let threadName = content.thread_name {
            payload["thread_name"] = threadName
        }
        
        if let avatar = content.avatarURL {
            payload["avatar_url"] = avatar.absoluteString
        }
        
        if let embeds = content.embeds {
            let limitedEmbeds = embeds.prefix(10)
            if embeds.count > 10 {
                print("WARNING: Can't use more than 10 Embeds, only the first 10 Embeds will be used.")
            }
            
            let encoder = JSONEncoder()
            let embedData = try encoder.encode(Array(limitedEmbeds)) // Convert prefix to Array
            let embedJson = try JSONSerialization.jsonObject(with: embedData)
            payload["embeds"] = embedJson
        }

        
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"payload_json\"\r\n\r\n".data(using: .utf8)!)
        body.append(payloadData)
        body.append("\r\n".data(using: .utf8)!)
        
        for (index, file) in content.files.enumerated() {
            let fileData = file.content
            let fileName = file.fileName
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"files[\(index)]\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        if let string = String(data: responseData, encoding: .utf8) {
            print(string)
        }
        return (responseData, response)
    }
}

// https://discord.com/developers/docs/resources/webhook
public struct WebHook {
    public init(content: String? = nil, username: String? = nil, avatarURL: URL? = nil, tts: Bool? = nil, embeds: [Embed]? = nil, files: [DiscordFile], thread_name: String? = nil) {
        self.content = content
        self.username = username
        self.avatarURL = avatarURL
        self.tts = tts
        self.embeds = embeds
        self.files = files
        self.thread_name = thread_name
    }
    // the message contents (up to 2000 characters)
    var content: String?
    // override the default username of the webhook
    var username: String?
    // override the default avatar of the webhook
    var avatarURL: URL?
    // true if this is a TTS message
    var tts: Bool?
    // embedded rich content
    var embeds: [Embed]?
    // the contents of the file being sent
    var files: [DiscordFile]
    // name of thread to create (requires the webhook channel to be a forum or media channel)
    var thread_name: String?
    
    // https://discord.com/developers/docs/resources/message#embed-object
    public struct Embed: Codable {
        public init(title: String? = nil, description: String? = nil, url: String? = nil, color: DiscordColor? = nil, timestamp: String? = nil, author: Author? = nil, footer: Footer? = nil, fields: [Field]? = nil) {
            self.title = title
            self.description = description
            self.url = url
            self.color = color?.value
            self.timestamp = timestamp
            self.author = author
            self.footer = footer
            self.fields = fields
        }
        // title of embed
        var title: String?
        // description of embed
        var description: String?
        // url of embed
        var url: String?
        // color code of the embed
        var color: Int?
        // ISO8601 timestamp
        var timestamp: String?
        // author information
        var author: Author?
        // footer information
        var footer: Footer?
        // fields information, max of 25
        var fields: [Field]?
        
        // https://discord.com/developers/docs/resources/message#embed-object-embed-author-structure
        public struct Author: Codable {
            init(name: String? = nil, url: String? = nil, icon_url: String? = nil) {
                self.name = name
                self.url = url
                self.icon_url = icon_url
            }
            var name: String?
            var url: String?
            var icon_url: String?
        }
        // https://discord.com/developers/docs/resources/message#embed-object-embed-footer-structure
        public struct Footer: Codable {
            init(text: String? = nil, icon_url: String? = nil) {
                self.text = text
                self.icon_url = icon_url
            }
            var text: String?
            var icon_url: String?
        }
        // https://discord.com/developers/docs/resources/message#embed-object-embed-field-structure
        public struct Field: Codable {
            init(name: String, value: String, inline: Bool? = nil) {
                self.name = name
                self.value = value
                self.inline = inline
            }
            var name: String
            var value: String
            var inline: Bool?
        }
    }
}

public struct DiscordFile {
    public init(content: Data, fileName: String) {
        self.content = content
        self.fileName = fileName
    }
    public init(from url: URL) throws {
        _ = url.startAccessingSecurityScopedResource()
        self.content = try Data(contentsOf: url)
        self.fileName = url.lastPathComponent
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            url.stopAccessingSecurityScopedResource()
        }
    }
    var content: Data
    var fileName: String
}

@frozen public struct DiscordColor: Codable, ExpressibleByIntegerLiteral {
    // CREDIT TO: https://gist.github.com/thomasbnt/b6f455e2c7d743b796917fa3c205f812
    public static let `default` = DiscordColor(0)
    public static let aqua = DiscordColor(1752220)
    public static let darkAqua = DiscordColor(1146986)
    public static let green = DiscordColor(5763719)
    public static let darkGreen = DiscordColor(2067276)
    public static let blue = DiscordColor(3447003)
    public static let darkBlue = DiscordColor(2123412)
    public static let purple = DiscordColor(10181046)
    public static let darkPurple = DiscordColor(7419530)
    public static let luminousVividPink = DiscordColor(15277667)
    public static let darkVividPink = DiscordColor(11342935)
    public static let gold = DiscordColor(15844367)
    public static let darkGold = DiscordColor(12745742)
    public static let orange = DiscordColor(15105570)
    public static let darkOrange = DiscordColor(11027200)
    public static let red = DiscordColor(15548997)
    public static let darkRed = DiscordColor(10038562)
    public static let grey = DiscordColor(9807270)
    public static let darkGrey = DiscordColor(9936031)
    public static let darkerGrey = DiscordColor(8359053)
    public static let lightGrey = DiscordColor(12370112)
    public static let navy = DiscordColor(3426654)
    public static let darkNavy = DiscordColor(2899536)
    public static let yellow = DiscordColor(16776960)
    public static let white = DiscordColor(16777215)
    public static let greyple = DiscordColor(10070709)
    public static let black = DiscordColor(2303786)
    public static let darkButNotBlack = DiscordColor(2895667)
    public static let notQuiteBlack = DiscordColor(2303786)
    public static let blurple = DiscordColor(5793266)
    public static let yellowOfficial = DiscordColor(16705372)
    public static let fuchsia = DiscordColor(15418782)
    public static let unnamedRole1 = DiscordColor(6323595)
    public static let unnamedRole2 = DiscordColor(5533306)
    public static let backgroundBlack = DiscordColor(3553599)
    
    let value: Int
    
    public static func fromHex(_ hexString: String) -> DiscordColor? {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        guard let intValue = Int(hex, radix: 16) else {
            return nil
        }
        return DiscordColor(intValue)
    }
    
    public init(_ colorCode: Int) {
        self.value = colorCode
    }
    
    public init(integerLiteral value: Int) {
        self.value = value
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(Int.self)
    }
}
