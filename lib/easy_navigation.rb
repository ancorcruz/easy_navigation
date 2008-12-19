module EasyNavigation

  module Helper
  
    def render_navigation(name)
    
      html = ""
      class_name = ""
      
      EasyNavigation::Builder.navigation[name][:tabs].each do |tab|
        menus_html = ""
        current_tab = false
        tab[:menus].each do |menu|
          class_name = "menu"
          if current_menu?(menu)
            class_name << " current"
            current_tab = true
          end 
          menus_html << content_tag("li", link_to(t(menu[:text]), menu[:url]), 
            :class => class_name, :id => menu[:name])
         if EasyNavigation::Builder.navigation[name][:options][:separator]
           menus_html << content_tag("li", "|", :class => "separator") 
         end
        end
        class_name = "tab"
        class_name << " current" if current_tab
        html << content_tag("li",
          "#{link_to(t(tab[:text]), tab[:url])} #{content_tag("ul", menus_html)}", 
          :class => class_name, :id => tab[:name])
      end
      content_tag("ul", html, :id => "navigation")
    end
    
    private

    def current_menu?(menu)
      current = controller.controller_name == menu[:url][:controller] && 
        (controller.action_name == menu[:url][:action] || menu[:url][:action] == nil)
      if menu.has_key?:on 
         (menu[:on].is_a?(Array) ? menu[:on] : [menu[:on]]).each do |controllers|
          (controllers.is_a?(Array) ? controllers : [controllers]).each do |c|
             current |= controller.controller_name == c[:controller]
            if c.has_key?:only
              current &= (c[:only].is_a?(Array) ? c[:only] : [c[:only]]).include?controller.action_name
            end
            if c.has_key?:except
              current &= !((c[:except].is_a?(Array) ? c[:except] : [c[:except]]).include?controller.action_name)
            end
          end
        end      
      end
      current
    end

  end # EasyNavigation::Helper

  class Configuration

    attr_accessor :navigation
    
    def initialize
      self.navigation = {}
    end
    
    def config(&block)
      builder = Builder.new
      yield builder
      builder.navigations.each { |tmp| 
        self.navigation[tmp[:name]] = tmp
      }
    end
    
    class Builder
      
      attr_accessor :navigations
    
      def initialize
        self.navigations = []
      end
        
      def navigation(name, options = {}, &block)
        navigation = Navigation.new(name, options.merge!(:prefix => "navigation"))
        yield navigation
        self.navigations << navigation.build
      end
      
      def build
        { :navigations => navigations }
      end
      
      class Navigation
      
        attr_accessor :tabs, :name, :options, :prefix
      
        def initialize(name, options = {})
          self.tabs = []
          self.name = name
          self.options = options
          self.prefix = options[:prefix]
        end
      
        def tab(name, options = {}, &block)
          tab = Tab.new(name, options.merge!(:prefix => [self.prefix, self.name]))
          yield tab
          self.tabs << tab.build
        end
        
        def build
          self.options[:separator] = false unless self.options.has_key?(:separator)
          { :name => self.name.to_sym, :tabs => self.tabs, :options => self.options }
        end
        
        class Tab
        
          attr_accessor :menus, :name, :url, :options, :prefix
          
          def initialize(name, options = {})
            self.menus = []
            self.name = name
            self.url = options[:url]
            self.options = options
            self.prefix = options[:prefix]
          end
          
          def menu(name, options = {}, &block)
            menu = Menu.new(name, options.merge!(:prefix => [self.prefix, self.name]))
            yield menu
            self.menus << menu.build
          end
          
          def build
            { :name => [self.prefix, self.name].join("_").to_sym, 
              :text => [self.prefix, self.name].join("."), 
              :url => self.url, 
              :options => self.options, 
              :menus => self.menus }
          end
          
          class Menu
            
            attr_accessor :name, :url, :options, :active_urls, :prefix
            
            def initialize(name, params = {})
              self.active_urls = []
              self.name = name
              self.url = params[:url]
              self.options = params
              self.prefix = params[:prefix]
            end
            
            def build
              self.prefix << self.name
              { :name => self.prefix.join("_").to_sym, 
                :text => self.prefix.join("."), 
                :url => self.url, 
                :on => self.active_urls }
            end
            
            def connect(options = {})
              options[:controller] = self.options[:url][:controller] unless options.has_key?(:controller)
              self.active_urls << options
            end

          end #Menu
        end # Tab
      end # Navigation
    end # Builder
  end # Configuration
  
  Builder = Configuration.new
  
end# EasyNavigation
