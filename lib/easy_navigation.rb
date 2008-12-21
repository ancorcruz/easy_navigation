module EasyNavigation

  module Helper
  
    def easy_navigation(name, options = {})

      navigation_class_name = (options[:navigation_class] || "navigation").to_s
      tab_class_name = (options[:tab_class] || "tab").to_s
      menu_class_name = (options[:menu_class] || "menu").to_s
      separator_class_name = (options[:separator_class] || "separator").to_s
      separator = options[:separator] || false

      tabs_html = ""
      
      EasyNavigation::Builder.navigation[name][:tabs].each do |tab|
        menus_html = ""
        current_tab = false
        tab[:menus].each do |menu|
          if current = current_menu?(menu)
            current_tab = true
          end
          menus_html << self.render_menu(menu[:name], menu[:text], 
            menu[:url].merge!(:skip_relative_url_root => true), 
            ("#{menu_class_name} current" if current) || menu_class_name)
          if separator
           menus_html << self.render_separator(separator_class_name)
          end
        end
        tabs_html << self.render_tab(tab[:name], 
          tab[:text], 
          tab[:url].merge!(:skip_relative_url_root => true), 
          menus_html, ("#{tab_class_name} current" if current_tab) || tab_class_name)
      end
      self.render_navigation("navigation_" << name.to_s, tabs_html, navigation_class_name)
    end
    
    protected
    
    def render_separator(class_name)
      content_tag("li", "|", :class => class_name)
    end
    
    def render_menu(id, text, url, class_name)
      content_tag("li", link_to(t(text), url), :id => id, :class => class_name)
    end
    
    def render_tab(id, text, url, menus_html, class_name)
      content_tag("li",
        "#{link_to(t(text), url)} #{content_tag("ul", menus_html)}",
        :id => id, :class => class_name)
    end
    
    def render_navigation(id, tabs_html, class_name)
      content_tag("ul", tabs_html, :id => id, :class => class_name)
    end
    
    def current_menu?(menu)
      current = controller.params[:controller] == menu[:url][:controller].gsub(/^\//, "") && 
        (controller.action_name == menu[:url][:action] || menu[:url][:action] == nil)
      if menu.has_key?:on 
         (menu[:on].is_a?(Array) ? menu[:on] : [menu[:on]]).each do |controllers|
          (controllers.is_a?(Array) ? controllers : [controllers]).each do |c|
             current |= controller.params[:controller] == c[:controller].gsub(/^\//, "")
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
      
        attr_accessor :tabs, :name, :options
      
        def initialize(name, options = {})
          self.tabs = []
          self.name = name
          self.options = options
        end
      
        def tab(name, options = {}, &block)
          tab = Tab.new(name, options.merge!(:prefix => [self.options[:prefix], self.name]))
          yield tab
          self.tabs << tab.build
        end
        
        def build
          self.options[:separator] = false unless self.options.has_key?(:separator)
          { :name => self.name.to_sym, :tabs => self.tabs, :options => self.options }
        end
        
        class Tab
        
          attr_accessor :menus, :name, :options
          
          def initialize(name, options = {})
            self.menus = []
            self.name = name
            self.options = options
          end
          
          def menu(name, options = {}, &block)
            menu = Menu.new(name, options.merge!(:prefix => [self.options[:prefix], self.name, "menus"]))
            yield menu
            self.menus << menu.build
          end
          
          def build
            { :name => [self.options[:prefix], self.name].join("_").to_sym, 
              :text => [self.options[:prefix], self.name, "title"].join("."), 
              :url => self.options[:url],
              :options => self.options, 
              :menus => self.menus }
          end
          
          class Menu
            
            attr_accessor :name, :options, :active_urls
            
            def initialize(name, params = {})
              self.active_urls = []
              self.name = name
              self.options = params
            end
            
            def build
              self.options[:prefix] << self.name
              { :name => self.options[:prefix].join("_").to_sym, 
                :text => self.options[:prefix].join("."), 
                :url => self.options[:url], 
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
  
end # EasyNavigation

ActionView::Base.send :include, EasyNavigation::Helper
