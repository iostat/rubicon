require "digest/md5"

module Rubicon::Frostbite::BF3
    class Server
        require 'rubicon/frostbite/bf3/signal_handlers'
        require 'rubicon/frostbite/bf3/event_handlers'

        attr_reader :connection, :logger # logger is really only here for event_handlers.
        attr_accessor :name, :players, :max_players, :game_mode,
            :current_map, :rounds_played, :rounds_total, :scores,
            :score_target, :online_state, :ranked, :punkbuster,
            :has_password, :uptime, :round_time, :ip,
            :punkbuster_version, :join_queue, :region,
            :closest_ping_site, :country, :matchmaking,
            :teams, :plugin_manager

        def initialize(connection, password)
            @connection = connection
            @password = password
            @logger = Rubicon.logger("BF3Server")

            @players = {}
            @teams = []

            # 0 = neutral, 16 possible teams
            17.times do |idx|
                @teams[idx] = Team.new(self, idx)
            end

            @players["Server"] = SpecialPlayer.new(self, "Server")
        end

        # Called when successfully connected to a BF3 RCON server
        def connected
            @logger.debug { "Connected to a BF3 server!" }

            process_signal(:refresh_server_info)

            @logger.info { "Connected to #{@name}!" }

            if !attempt_login
                @logger.fatal { "Failed to log in!" }
                return false
            end

            process_signal(:refresh_scoreboard)

            @plugin_manager = Rubicon::PluginManager.new(self)
            @connection.send_command "admin.eventsEnabled", "true"

            return true
        end

        # Attempts to log in using a hashed password
        def attempt_login
            salt_packet = @connection.send_request("login.hashed")
            
            salt = salt_packet.words[1]
            result = @connection.send_request("login.hashed", hash_password(salt))

            result.response == "OK"
        end

        # Hashes a password given a HexString-encoded salt
        def hash_password(salt)
            salt = [salt].pack("H*")
            salted_password = salt + @password
            Digest::MD5.hexdigest(salted_password).upcase
        end

        # Process signals and events
        def start_event_pump
            while message = @connection.message_channel.receive
                if (message.is_a? Rubicon::Frostbite::RconPacket)
                    process_event(message)
                elsif (message.is_a? Symbol)
                    if (message == :shutdown)
                        shutdown!
                        break
                    end
                    process_signal(message)
                else
                    @logger.warn("Discarding unknown message: #{message}")
                end
            end
            @logger.info { "Event pump stopped. Shutting down like a boss."}
        end

        def process_signal(signal)
            if @@signal_handlers[signal]
                @@signal_handlers[signal].call(self)
            else
                @logger.warn { "No handler for signal #{signal}" }
            end
        end

        def process_event(event)
            if @@event_handlers[event.words[0]]
                begin
                    @@event_handlers[event.words[0]].call(self, event)
                rescue Exception => e
                    @logger.error { "Exception processing event #{event.words[0]}" }
                    @logger.error { "Offending packet: #{event.inspect}"}
                    @logger.error "Exception in plugin: #{e.message} (#{e.class})"
                    @logger.error (e.backtrace || [])[0..10].join("\n")
                end
            else
                @logger.warn { "No handler for packet #{event.words[0]}" }
            end
        end     
    end

    # Registers our server state manager
    Rubicon::Frostbite::RconClient::game_handlers["BF3"] = Server
end