require 'securerandom'
require_relative 'config'

DOMAIN="buddha2.com"

module Subscription

module Messages

INVALID_EMAIL = 'Ошибочный адрес почты.'
INVALID_KEY = 'Ошибочная ссылка на подписку.'
ALREADY_SUBSCRIBED = 'Вы уже подписаны.'

end

class Exception < StandardError
  def initialize(message)
    super(message)
  end
end

def Subscription.validate(email)
  r = RestClient.get(
    "https://#{Config::MAILGUN_AUTH_PUB}@api.mailgun.net/v3/address/validate",
    params: { address: email }
  )
  return if JSON.parse(r)['is_valid']

  raise Exception.new(Messages::INVALID_EMAIL)
end

def Subscription.check_status(email)
  sub = DB[:subscriptions][email: email]
  return if sub.nil?

  raise Subscription::Exception.new(Messages::ALREADY_SUBSCRIBED)
end

def Subscription.mailgun_api(address)
    "https://#{Config::MAILGUN_AUTH_PRIV}@api.mailgun.net/v3/" + address
end

def Subscription.send_html(email, subject, html)
  r = RestClient.post(Subscription::mailgun_api("#{DOMAIN}/messages"),
    {
      from: "#{DOMAIN} <system@#{DOMAIN}>",
      to: email,
      subject: subject,
      html: html
    }
  )

  raise StandardError if r.code != 200
end

def Subscription.send_activation(email, key)

  r = RestClient.post(mailgun_api("#{DOMAIN}/messages"),
    {
      from: "#{DOMAIN} <system@#{DOMAIN}>",
      to: email,
      subject: "Активизируйте свою подписку на сайт buddha.ru",
      text: <<-END
Для активации перейдите по ссылке
 http://#{DOMAIN}/subscription/activate?key=#{key}
      END
    }
  )

  raise StandardError if r.code != 200
end

def Subscription.subscribe(email)
  validate(email)
  check_status(email)

  key = SecureRandom.hex(10)
  send_activation(email, key)

  DB[:subscriptions].insert(email: email, key: key)
end

def Subscription.subscribe_list(list, subscription)
  r = RestClient.post(mailgun_api("lists/#{list}@#{DOMAIN}/members"),
    {
      subscribed: true,
      address: subscription[:email],
      vars: JSON.dump({ 'key' => subscription[:key] })
    }
  )
  raise StandardError if r.code != 200
end

def Subscription.already_exist(e)
  not /already exists/.match(JSON.parse(e.response)['message']).nil?
end

def Subscription.subscribe_list_safe(list, subscription)
  begin
    subscribe_list(list, subscription)
  rescue RestClient::BadRequest => e
    raise e if not already_exist(e)
  end
end

def Subscription.unsubscribe_list(list, email)
  r = RestClient.delete(mailgun_api("lists/#{list}@#{DOMAIN}/members/#{email}"))
  raise StandardError if r.code != 200
end

def Subscription.unsubscribe_list_safe(list, email)
  begin
    unsubscribe_list(list, email)
  rescue RestClient::ResourceNotFound => e
  end
end

def Subscription.in_list(list, email)
  begin
    r = RestClient.get(mailgun_api("lists/#{list}@#{DOMAIN}/members/#{email}"))
  rescue RestClient::ResourceNotFound
    return false
  end
  true
end

def Subscription.activate(key)
  sub = DB[:subscriptions][key: key]
  raise Exception.new(Messages::INVALID_KEY) if sub.nil?
  subscribe_list_safe('news', sub)
  subscribe_list_safe('library', sub)
  subscribe_list_safe('timetable', sub)
  {
    key: key,
    on_news: true,
    on_books: true,
    on_timetable: true
  }
end

def Subscription.check(key)
  sub = DB[:subscriptions][key: key]
  raise Exception.new(Messages::INVALID_KEY) if sub.nil?
  email = sub[:email]
  {
    key: key,
    on_news: in_list('news', email),
    on_books: in_list('library', email),
    on_timetable: in_list('timetable', email)
  }
end

def Subscription.sync_subscription(list, subscription, state)
  if (state)
    subscribe_list_safe(list, subscription)
  else
    unsubscribe_list_safe(list, subscription[:email])
  end
end

def Subscription.manage(params)
  sub = DB[:subscriptions][key: params['key']]
  raise Exception.new(Messages::INVALID_KEY) if sub.nil?
  sync_subscription('news', sub, params['on_news'])
  sync_subscription('library', sub, params['on_books'])
  sync_subscription('timetable', sub, params['on_timetable'])
  {
    key: params['key'],
    on_news: params['on_news'],
    on_books: params['on_books'],
    on_timetable: params['on_timetable']
  }
end

def Subscription.unsubscribe(key)
  sub = DB[:subscriptions][key: key]
  raise Exception.new(Messages::INVALID_KEY) if sub.nil?
  email = sub[:email]
  unsubscribe_list_safe('news', email)
  unsubscribe_list_safe('library', email)
  unsubscribe_list_safe('timetable', email)
  DB[:subscriptions].where(key: key).delete
end

end
