// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import OpenTelemetrySdk

public class ZipkinTraceExporter: SpanExporter {
    public private(set) var options: ZipkinTraceExporterOptions
    var localEndPoint: ZipkinEndpoint

    public init(options: ZipkinTraceExporterOptions) {
        self.options = options
        localEndPoint = ZipkinTraceExporter.getLocalZipkinEndpoint(name: "Open Telemetry Exporter")
    }

    public func export(spans: [SpanData]) -> SpanExporterResultCode {
        guard let url = URL(string: self.options.endpoint) else { return .failure }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: encodeSpans(spans: spans), options: [])
        } catch {
            return .failure
        }

        var status: SpanExporterResultCode = .failure

        let sem = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { _, _, error in
            if error != nil {
                status = .failure
            } else {
                status = .success
            }
            sem.signal()
        }
        task.resume()
        sem.wait()

        return status
    }

    public func flush() -> SpanExporterResultCode {
        return .success
    }

    public func shutdown() {
    }

    func encodeSpans(spans: [SpanData]) -> [Any] {
        return spans.map { ZipkinConversionExtension.toZipkinSpan(otelSpan: $0, defaultLocalEndpoint: localEndPoint) }
    }

    static func getLocalZipkinEndpoint(name: String? = nil) -> ZipkinEndpoint {
        let hostname = name ?? ProcessInfo.processInfo.hostName
        #if os(OSX)
            let ipv4 = Host.current().addresses.first { NetworkUtils.isValidIpv4Address($0) }
            let ipv6 = Host.current().addresses.first { NetworkUtils.isValidIpv6Address($0) }
            return ZipkinEndpoint(serviceName: hostname, ipv4: ipv4, ipv5: ipv6, port: nil)
        #else
            return ZipkinEndpoint(serviceName: hostname)
        #endif
    }
}
