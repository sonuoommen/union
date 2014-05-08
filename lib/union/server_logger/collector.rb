module Union::ServerLogger
  # Collects OSSEC logs from specified servers.
  class Collector
    def initialize
      # Use default logger
      Union::Log.logger = begin
        Logger.new STDOUT
      end
    end

    # Executes run_and_collect_logs and save_logs in a time loop for servers
    def run
      every 1.hour do
        servers = Server.where(logging: true)
        servers.each do |s|
          logs = run_and_collect_logs(s)
          save_logs(logs, s)
        end
      end
    end

    # Connects to server and runs ossec log collector
    # @param server [Server] Server object.
    # @return [JSON] Logs returned from server or an error message
    def run_and_collect_logs(s)
      name = s.hostname
      server = HashWithIndifferentAccess.new(
          host: s.hostname,
          username: s.login_user,
          port: s.port
      )

      conn = Union::ServerConnection.new(name, server)

      begin
        conn.execute_logger(APP_CONFIG['ossec_collector_path'])
      rescue Exceptions::ServerLoggerExecutableMissing, SocketError => e
        message = "Couldn't collect logs from #{name} : #{e.message}"
        Union::Log.error message
        { Time.now.to_f => [ message ] }.to_json
      end
    end

    # Saves logs to database
    # @param logs [JSON] data from server or error.
    # @param server [Server] ActiveRecord server object.
    def save_logs(logs, server)
      logs = JSON.parse(logs)
      logs.each do |time, data|
        server_log = server.server_logs.new(timestamp: time, log: data)
        server_log.save
      end
    end
  end
end