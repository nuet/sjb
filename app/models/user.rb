class User < ActiveRecord::Base
  include ConfigManager

  belongs_to :profile
  #belongs_to :text_filter
  has_one :resource , as: :file, dependent: :destroy
  has_one :user_payment,dependent: :destroy
  has_one :user_bank,dependent: :destroy
  has_one :ssc_journal,dependent: :destroy

  has_many :payments
  has_many :orders
  has_many :ssc_orders
  has_many :ssc_journal_logs,dependent: :destroy

  #delegate :name, to: :text_filter, prefix: true
  delegate :label, to: :profile, prefix: true

  # has_many :notifications, foreign_key: 'notify_user_id'
  # has_many :notify_contents, -> { uniq }, through: :notifications,
  #          source: 'notify_content'
  #
  # has_many :articles

  serialize :settings, Hash

  STATUS = %w(active inactive black white)

  attr_accessor :filename

  # Settings

  # echo "publify" | sha1sum -
  class_attribute :salt

  scope :admin, -> {

    joins(:profile).
        where(profiles:{label:'admin'})
  }

  scope :agent, -> {

    joins(:profile).
        where(profiles:{label:'agent'})
  }

  scope :default,-> {

    joins(:profile).
        where(profiles:{label:'contributor'})

  }

  def self.salt
    '20ac4d290c2293702c64b3b287ae5ea79b26a5c1'
  end

  attr_accessor :last_venue

  def self.authenticate(login, pass)
    find_by('login = ? AND password = ?', login, password_hash(pass))# AND state = ? , 'active'
  end

  def update_connection_time
    self.last_venue = last_connection
    self.last_connection = Time.now
    save
  end

  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    remember_me_for 3.months
  end

  def remember_me_for(time)
    remember_me_until time.from_now.utc
  end

  def remember_me_until(time)
    self.remember_token_expires_at = time
    self.remember_token = Digest::SHA1.hexdigest("#{self.login}--#{self.remember_token_expires_at}")
    save(validate: false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token = nil
    save(validate: false)
  end

  def self.authenticate?(login, pass)
    user = authenticate(login, pass)
    return false if user.nil?
    return true if user.login == login

    false
  end

  def self.find_by_permalink(permalink)
    find_by_login(permalink).tap do |user|
      raise ActiveRecord::RecordNotFound unless user
    end
  end

  delegate :project_modules, to: :profile

  # AccessControl.available_modules.each do |m|
  #   define_method("can_access_to_#{m}?") { can_access_to?(m) }
  # end

  # def can_access_to?(m)
  #   profile.modules.include?(m)
  # end

  # Generate Methods takes from AccessControl rules
  # Example:
  #
  #   def publisher?
  #     profile.label == :publisher
  #   end


  # AccessControl.roles.each do |role|
  #   define_method "#{role.to_s.downcase}?" do
  #     profile.label.to_s.downcase == role.to_s.downcase
  #   end
  # end

  def self.to_prefix
    'author'
  end

  attr_writer :password

  attr_writer :verify_password

  def password(cleartext = nil)
    if cleartext
      @password.to_s
    else
      @password || self[:password]
    end
  end

  def verify_password(cleartext = nil)
    if cleartext
      @verify_password.to_s
    else
      @verify_password || self[:verify_password]
    end
  end

  def article_counter
    articles.size
  end

  def effective_journal1
    #一级流水
    self.effective_journal.round(2)
  end

  def effective_journal2
    #二级流水
    User.where(referee:self.id).sum('effective_journal').round(2)
  end

  def effective_journal3
    #三级流水
    referee=[]
    User.where(referee:self.id).each do |ele|
      referee << ele.id
    end
    User.where(referee:referee).sum('effective_journal').round(2)
  end

  def referee_user_1
    User.where(referee:self.id).count
  end
  def referee_user_2
    referee=[]
    User.where(referee:self.id).each do |ele|
      referee << ele.id
    end
    User.where(referee:referee).count
  end
  def referee_user_3
    referee=[]
    referees=[]
    User.where(referee:self.id).each do |ele|
      referee << ele.id
    end
    User.where(referee:referee).each do |ele|
      referees << ele.id
    end
    User.where(referee:referees).count
  end

  def sum_journal
    #可提现金额
    val=self.effective_journal1*(((Setting.where(category:'rebate')[0] || Setting.new(category:'rebate')).val).to_f)
    val+=self.effective_journal2*(((Setting.where(category:'rebate2')[0] || Setting.new(category:'rebate2')).val).to_f)
    val+=self.effective_journal3*(((Setting.where(category:'rebate3')[0] || Setting.new(category:'rebate3')).val).to_f)
    return val.round(2)
  end

  def display_name
    if !nickname.blank?
      nickname
    elsif !name.blank?
      name
    else
      login
    end
  end

  def permalink
    login
  end

  def admin?
    profile.label == Profile::ADMIN
  end

  def generate_password!
    chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    newpass = ''
    1.upto(7) { |_i| newpass << chars[rand(chars.size - 1)] }
    self.password = newpass
  end

  def update_password(pass)
    @password = pass
    save
  end

  def update_verify_password(pass)
    @verify_password = pass
    save
  end

  def self.password_hash(pass)
    Digest::SHA1.hexdigest("#{salt}--#{pass}--")
  end

  protected

  # Apply SHA1 encryption to the supplied password.
  # We will additionally surround the password with a salt
  # for additional security.

  def password_hash(pass)
    self.class.password_hash(pass)
  end

  before_create :crypt_password

  before_create :crypt_verify_password


  # Before saving the record to database we will crypt the password
  # using SHA1.
  # We never store the actual password in the DB.
  # But before the encryption, we send an email to user for he can remind his
  # password
  def crypt_password
    # EmailNotify.send_user_create_notification self
    self[:password] =
        password_hash(password(true))
    @password = nil
  end

  def crypt_verify_password
    if verify_password(true).empty?
      self[:verify_password] =  self[:password]
    else
      self[:verify_password] = password_hash(verify_password(true))
      @verify_password = nil
    end
  end

  before_update :crypt_unless_empty
  # If the record is updated we will check if the password is empty.
  # If its empty we assume that the user didn't want to change his
  # password and just reset it to the old value.
  def crypt_unless_empty
    if password(true).empty?
      user = self.class.find(id)
      self[:password] = user.password
    else
      crypt_password
    end

    if verify_password(true).empty?
      user = self.class.find(id)
      self[:verify_password] = user.verify_password
    else
      crypt_verify_password
    end

  end

  before_validation :set_default_profile

  def set_default_profile
    self.profile ||= Profile.find_by_label(User.count.zero? ? 'admin' : 'contributor')
  end

  # validates :login,presence: {  message: 'is forgotten.' }, uniqueness: true, on: :create #if: :login_required?,
  # validates :email ,presence: {  message: 'is forgotten.' },uniqueness: true, on: :create
  validates :password, length: {in: 5..40,message:"请输入5位以上的密码长度"}, if: proc { |user|
    user.read_attribute('password').nil? or user.password.to_s.length > 0
  }

  # validates :email, :login, presence: false

  validates_presence_of :login,:message => "用户名不能为空"

  validates_uniqueness_of :login,:case_sensitive => false,:message => "此用户名已被注册"

  validates :password, confirmation: true
  validates :login, length: {in: 3...40,message: "请输入3位以上的用户名"}



end
