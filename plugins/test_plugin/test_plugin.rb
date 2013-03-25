# encoding: utf-8
class MyTestPlugin < Rubicon::Plugin
    enabled do
        @crosshair_icon = "(*)"

        # OS X rocks and has emoji in terminals
        os_x_version = `sw_vers -productVersion` rescue nil
        if os_x_version
            @crosshair_icon = "\u{1F3AF} " if os_x_version.match /^10\.[78]/
        end
    end

    event "player.onKill" do
        logger.event(:kill) { "[KILL] " + "#{killer.name.rjust 16} #{"[#{@crosshair_icon if headshot?}#{weapon.name}]".center 18} #{victim.name}" }
    end

    event "player.onSuicide" do
        logger.event(:suicide) { "[SCDE] #{player.name} killed themselves via #{weapon.name}" }
    end

    command :rbcshutdown do
        logger.info "Shutdown issued by #{player.name}!"
        server.connection.close_connection
    end
end