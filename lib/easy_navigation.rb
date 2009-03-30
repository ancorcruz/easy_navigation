module EasyNavigation

  module Helper
  
    def easy_navigation(name, options = {})
      navigation_class_name = (options[:navigation_class] || "navigation").to_s
      tab_class_name = (options[:tab_class] || "tab").to_s
      separator_class_name = (options[:separator_class] || "separator").to_s
      separator = options[:separator] || false
      deep_level = options[:deep_level] || 0

      tabs_html = render_tabs(EasyNavigation::Builder.navigation[name], 0, deep_level, tab_class_name)
      self.render_navigation("navigation_" << name.to_s, tabs_html, navigation_class_name)
    end
    
    protected
    
    def render_tabs(tab, deep, deep_level, tab_class_name)
      tabs_html = ''
      if deep == deep_level
        active_tab = current_tab?(tab)
        
        tab[:tabs].each do |subtab|
          tab_class = tab_class_name
          tab_class += " first" if tabs_html.empty?
          tab_class += " active" if current_tab?(subtab)
          tab_class = tab_class.strip

          if active_tab && user_authorized_tab?(subtab)
            tabs_html << self.render_tab(subtab[:name],
               subtab[:text],
               action_for_tab(subtab)[:url].merge!(:skip_relative_url_root => true),
               tab_class)
          end
        end
      else
        tab[:tabs].each do |subtab|
          tabs_html = render_tabs(subtab, deep + 1, deep_level, tab_class_name)
          return tabs_html unless tabs_html.empty?
        end
      end
      tabs_html
    end

    # This code could be better but works!
    def current_tab?(tab)
      if tab[:tabs].empty?
        if tab[:url][:action]
          return (controller.params[:controller] == tab[:url][:controller] &&
                     controller.params[:action] == tab[:url][:action]) ||
                     (tab[:clones].include? controller.params[:controller])
        else
          return (controller.params[:controller] == tab[:url][:controller] &&
                     controller.params[:action] == 'index') || 
                     (tab[:clones].include? controller.params[:controller])
        end
      else
        tab[:tabs].each { |subtab| return true if current_tab?(subtab) }
      end
      false
    end

    def action_for_tab(tab)
      return tab unless controller.class.methods.include?("user_authorized_for?") 
      return tab if (tab[:url][:controller] + "_controller").camelize.constantize.user_authorized_for?(current_user, { :action => tab[:url][:action] }, binding)
      
      tab[:tabs].each { |subtab| return subtab if action_for_tab(subtab) } unless tab[:tabs].empty?
      nil
    end

    # This code could be better but works!
    def user_authorized_tab?(tab)
      return true unless controller.class.methods.include?("user_authorized_for?") 
      tab[:tabs].each { |subtab| return true if user_authorized_tab?(subtab) } unless tab[:tabs].empty?
      
      if tab[:url][:action]
        return (tab[:url][:controller] + "_controller").camelize.constantize.user_authorized_for?(current_user, { :action => tab[:url][:action] }, binding)
      else
        return (tab[:url][:controller] + "_controller").camelize.constantize.user_authorized_for?(current_user, { :action => 'index' }, binding)
      end
    end

    def render_separator(class_name)
      content_tag("li", "|", :class => class_name)
    end
    
    def render_tab(id, text, url, class_name)
      content_tag("li", link_to(t(text), url), :id => id, :class => class_name)
    end

    def render_navigation(id, tabs_html, class_name)
      content_tag("ul", tabs_html, :id => id, :class => class_name)
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
        yield navigation if block
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
          yield tab if block
          self.tabs << tab.build
        end
        
        def build
          self.options[:separator] = false unless self.options.has_key?(:separator)
          { :name => self.name.to_sym, :tabs => self.tabs, :options => self.options }
        end
        
        class Tab
        
          attr_accessor :tabs, :clones, :name, :options
          
          def initialize(name, options = {})
            self.tabs = []
            self.clones = []
            self.name = name
            self.options = options
          end

          def clone(options)
            self.clones << options[:controller]
          end

          def tab(name, options = {}, &block)
            tab = Tab.new(name, options.merge!(:prefix => [self.options[:prefix], self.name]))
            yield tab if block
            self.tabs << tab.build
          end

          def build
            { :name => [self.options[:prefix], self.name].join("_").to_sym, 
              :text => [self.options[:prefix], self.name, "title"].join("."), 
              :url => self.options[:url],
              :options => self.options,
              :tabs => self.tabs,
              :clones => self.clones }
          end

        end # Tab
      end # Navigation
    end # Builder
  end # Configuration
  
  Builder = Configuration.new
  
end # EasyNavigation

ActionView::Base.send :include, EasyNavigation::Helper
