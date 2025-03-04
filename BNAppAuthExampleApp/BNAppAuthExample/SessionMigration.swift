import Foundation

class SessionMigration {
    let urlSession: URLSession
    
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    struct MagicLink: Decodable {
        let loginToken: String
    }
    
    enum SessionMigrationError: Error {
        case couldNotGetMagicLink
    }
    
    func getMagicLinkToken(
        url: URL,
        headers: [String:String]? = nil,
        completion: @escaping ((Result<String,Error>) -> Void)
    ) {
        var request = URLRequest(url: url)
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let dataTask = urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let data = data, let magicLink = try? JSONDecoder().decode(MagicLink.self, from: data) {
                completion(.success(magicLink.loginToken))
            } else {
                completion(.failure(SessionMigrationError.couldNotGetMagicLink))
                return
            }
        }

        dataTask.resume()
    }
}
