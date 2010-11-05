#!/usr/bin/env ruby

require 'rubygems'
require 'ffi-rzmq'
require 'yaml'

class Capitalist
  
  def initialize
    puts self.class
    @ctx = ZMQ::Context.new(1)
  end
  
  def die!
    @ctx.terminate
  end
  
end

class Manager < Capitalist
  
  def initialize(nap_time, all_employees_mail_list_address)
    super()
    @nap_time = nap_time
    @all_employees_mail_list = @ctx.socket(ZMQ::PUB)
    @all_employees_mail_list.bind(all_employees_mail_list_address)
    @things_i_want = ['coffee', 'lunch', 'money', 'new boat', 'convertible car']
  end
  
  def work!
    loop do
      @things_i_want.each do |thing|
        sleep @nap_time
        send_everyone_a_message("I want: #{thing}")
      end
    end  
  end
  
  private
  
  def send_everyone_a_message(msg)
    puts "[Manager] #{msg}"
    @all_employees_mail_list.send_string(msg)
  end
  
end

class Employee < Capitalist
  
  def initialize(my_employee_id, my_mail_address, outsource_phone_number)
    super()
    @my_employee_id = my_employee_id
    @all_employees_mail_list = @ctx.socket(ZMQ::SUB)
    @all_employees_mail_list.setsockopt(ZMQ::SUBSCRIBE, 'I want')
    @all_employees_mail_list.connect my_mail_address
    
    @outsource_phone = @ctx.socket(ZMQ::REQ)
    @outsource_phone.connect outsource_phone_number
  end
  
  def work!
    loop do
      what_my_boss_wants = read_my_email
      cheer "Yeah, a new message from my mighty boss. I will outsource '#{what_my_boss_wants}' to some 3rd World Country."
      reply = call_the_outsource_and_ask_for what_my_boss_wants
      cheer "Hooray, it's done! The outsource just replied: #{reply}"
    end
  end
  
  private
  
  def read_my_email
    msg = @all_employees_mail_list.recv_string
    msg =~ /I want: (.*)/
    $1
  end
  
  def call_the_outsource_and_ask_for(what_my_boss_wants)
    @outsource_phone.send_string("I need: #{what_my_boss_wants}")
    @outsource_phone.recv_string
  end
  
  def cheer(phrase)
    puts "[Employee #{@my_employee_id}] #{phrase}"
  end
  
end

class ThirdWorldPoorCountryManager < Capitalist
  
  def initialize(my_employee_id, my_phone_number, factory_phone_number)
    super()
    @my_employee_id = my_employee_id
    @my_phone = @ctx.socket(ZMQ::REP)
    @my_phone.bind my_phone_number
    
    @trabajadores = @ctx.socket(ZMQ::PUSH)
    @trabajadores.bind factory_phone_number
  end
  
  def work!
    loop do
      request = wait_for_gringos_call
      scream "Maaaan, the gringo needs #{request}. Let's work cabrones!"
      notify_gringo_that_its_being_done request
    end
  end
  
  private
  
  def wait_for_gringos_call
    msg = @my_phone.recv_string
    msg =~ /I need: (.*)/
    $1
  end
  
  def put_people_back_to_work_and_make(request)
    request.each_char do |c|
      @trabajadores.send_string("Do it: #{c}")
    end
  end
  
  def notify_gringo_that_its_being_done(product)
    @my_phone.send_string("Sir, your #{product} is being processed and will be shipped soon. Thank you.")
  end
  
  def scream(phrase)
    puts "[Outsource #{@my_employee_id}] #{phrase}"
  end
  
end

class ThirdWorldPoorCountryRealWorker < Capitalist
  
  def initialize(my_employee_id, my_factory_phone_number)
    super()
    @my_employee_id = my_employee_id
    @jefe = @ctx.socket(ZMQ::PULL)
    @jefe.connect my_factory_phone_number
  end
  
  def work!
    loop do
      order = listen_to_my_boss
      mourn "¡Ay, caramba! I have to do a #{order}"
      result = produce order
      mourn "Done! Here is the #{result}"
    end
  end
  
  private
  
  def listen_to_my_boss
    msg = @jefe.recv_string
    msg =~ /Do it: (.*)/
    $1
  end
  
  def produce(order)
    order.upcase
  end
  
  def mourn(phrase)
    puts "[Worker #{@my_employee_id}] #{phrase}"
  end
  
end

def configurate
  configs = YAML::load(open 'jobs_conf.yml')
  
  @@PROTOCOL = configs['protocol']
  @@WARM_UP_TIME = configs['warm_up_time']
  
  configs
end

def run
  job = ARGV[0]
  type = ARGV[1]
  qty = ARGV[2].to_i
  configs = configurate
  configs = configs[job][type]
  raise "Type of #{job} not found." if not configs
  
  dudes = []
  case job
  when 'manager'
    qty.times do |i|
      dudes << Manager.new( configs['nap_time'], 
                            "#{@@PROTOCOL}://#{configs['accept_conections_from_address']}:#{configs['accept_conections_from_port']}" )
    end
    
  when 'employee'
    qty.times do |i|
      dudes << Employee.new( (i+1), 
                            "#{@@PROTOCOL}://#{configs['boss_address']}:#{configs['boss_port']}", 
                            "#{@@PROTOCOL}://#{configs['outsource_address']}:#{configs['outsource_port']}" )
    end
    
  when 'worker_manager'
    qty.times do |i|
      dudes << ThirdWorldPoorCountryManager.new( (i+1), 
                            "#{@@PROTOCOL}://#{configs['accept_requests_from_address']}:#{configs['accept_requests_from_port']}",
                            "#{@@PROTOCOL}://#{configs['forward_requests_to_address']}:#{configs['forward_requests_to_port']}" )
    end
    
  when 'poor_worker'
    qty.times do |i|
      dudes << ThirdWorldPoorCountryRealWorker.new( (i+1),
                            "#{@@PROTOCOL}://#{configs['boss_address']}:#{configs['boss_port']}" )
    end

  else
    raise "Hey dude, we don't have this kind of job over here: #{job}"
  end
  
  sleep @@WARM_UP_TIME
  working_dudes = []
  dudes.each { |dude| working_dudes << Thread.new { dude.work! } }
  working_dudes.each { |dude| dude.join }
  dudes.each { |dude| dude.die! }
  
end

begin
  run
rescue Exception => e
  puts $!
ensure
  puts "Out!"
end