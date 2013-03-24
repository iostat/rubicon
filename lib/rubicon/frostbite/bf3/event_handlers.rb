class Rubicon::Frostbite::BF3::Server
    @@event_handlers = {}
    def self.event(sig, &block)
        @@event_handlers[sig] = block
    end

    event "player.onKill" do |server, packet|
        event_name = packet.read_word
        event_args = {
            killer: server.players[packet.read_word],
            victim: server.players[packet.read_word],
            weapon: Rubicon::Frostbite::BF3::WEAPONS[packet.read_word],
            headshot?: packet.read_bool
        }
        
        server.plugin_manager.dispatch_event(event_name, event_args)
    end

    event "player.onChat" do |server, packet|
        event_name = packet.read_word
        player = server.players[packet.read_word]
        message = packet.read_word
        audience = packet.read_word

        if message[0] == "/"
            split_up = message.split " "
            command = split_up.shift
            command[0] = '' # remove the /
            args = { player: player, args: split_up}
            server.plugin_manager.dispatch_command(command, args)
        else
            event_args = {player: player, message: message, audience: audience }
            server.logger.info { "[CHAT] [#{audience}] <#{player.name}> #{message}" }
            server.plugin_manager.dispatch_event(event_name, event_args)
        end
    end
end