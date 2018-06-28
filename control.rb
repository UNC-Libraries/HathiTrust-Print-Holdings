WORKDIR = 'output/'

def govern(commands:, proc_limit:, sleeptime:)
  return if commands.empty?
  procs = {}
  retried = []
  until commands.empty?
    until procs.length >= proc_limit || commands.empty?
      command = commands.shift
      pid = start_proc(command)
      procs[pid] = command
      sleep sleeptime
    end
    puts "commands exhausted or proc limit reached: #{procs}"
    finished = Process.wait
    if $?.exited? && $?.exitstatus == 0
      puts "#{finished} finished #{Time.now}"
      procs.delete(finished)
    else
      #if process fails do nothing
      procs.delete(finished)
    end
  end
  a = Process.waitall
end

def start_proc(command)
  proc = Process.spawn(command)
  puts "spawning #{proc}: time: #{Time.now} command: #{command}"
  proc
end


def bnum_lists
  bnum_lists = Dir.glob("#{WORKDIR}*.list").sort
  bnum_lists.map { |f| f.split('/')[-1] }
end

## get bnums
commands = ["ruby bin/get_bnums.rb"]
govern(commands: commands, proc_limit: 1, sleeptime: 1)

# process bnum lists

commands = bnum_lists.map { |file| "ruby bin/extract_holdings_data.rb #{file}" }
govern(commands: commands, proc_limit: 5, sleeptime: 5)


puts "Finished."
