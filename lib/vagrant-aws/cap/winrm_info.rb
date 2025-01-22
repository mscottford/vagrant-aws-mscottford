Vagrant.require "log4r"

require Vagrant.source_root.join("plugins/communicators/winrm/helper").to_s

module VagrantPlugins
  module AWS
    module Cap
      module WinRMInfo
        LOGGER = Log4r::Logger.new("vagrant::plugins::aws::winrm_info")

        def self.winrm_info(machine)
          info = {}
          info[:host] = CommunicatorWinRM::Helper.winrm_address(machine)
          info[:port] = CommunicatorWinRM::Helper.winrm_port(machine, info[:host] == "127.0.0.1")

          LOGGER.debug("WinRM password: #{machine.config.winrm.password.inspect}")

          if machine.config.winrm.password == :query_ec2 || machine.config.winrm.password == :query_ec2_retry
            machine.ui.info("Waiting for Windows Administrator password to be published...") if machine.config.winrm.password != :query_ec2_retry

            aws_profile = machine.provider_config.aws_profile
            keypair_path = machine.provider_config.keypair_path

            command = "aws ec2 get-password-data --instance-id #{machine.id} --priv-launch-key #{keypair_path} --output json"
            if !aws_profile.nil? && !aws_profile.empty?
              command += " --profile #{aws_profile}"
            end

            LOGGER.debug("Executing: #{command}")
            response = JSON.parse(`#{command}`)
            LOGGER.debug("Response: #{response.inspect}")

            machine.config.winrm.password = response["PasswordData"]
            LOGGER.debug("Windows password from response: #{machine.config.winrm.password.inspect}")

            if machine.config.winrm.password.nil? || machine.config.winrm.password.empty?
              LOGGER.debug("Windows password not available yet. Retrying after 30 seconds...")
              sleep(30)
              machine.config.winrm.password = :query_ec2_retry
              raise Errors::WinRMNotReady
            else
              LOGGER.debug("Windows password found.")  
            end
          end

          info
        end
      end
    end
  end
end

