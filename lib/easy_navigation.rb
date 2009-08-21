module EasyNavigation

  module Helper
    @@menu = nil
    def easy_navigation(name, options = {})
      navigation_class_name = (options[:navigation_class] || "navigation").to_s
      tab_class_name = (options[:tab_class] || "tab").to_s
      deep_level = options[:deep_level] || 0
      object_instance = options[:object_instance] || nil

      @@menu ||= menu_load

      tabs_html = render_tabs(EasyNavigation::Builder.navigation[name], 0, deep_level, tab_class_name, object_instance)
      self.render_navigation("navigation_" << name.to_s, tabs_html, navigation_class_name)
    end
    
    protected
    
    def render_tabs(tab, deep, deep_level, tab_class_name, object_instance)
      tabs_html = ''
      if deep == deep_level
        active_tab = current_tab?(tab)
        last_dropdown = nil

        tab[:tabs].each do |subtab|
          tab_class = tab_class_name
          tab_class += " #{subtab[:name]}"
          tab_class += " first" if tabs_html.empty?
          tab_class += " active" if ((current_tab?(subtab) && (object_instance.nil? || subtab[:options].nil? || subtab[:options][:object_instance].nil?)) ||
              (current_tab?(subtab) && object_instance && subtab[:options] && subtab[:options][:object_instance] && object_instance == subtab[:options][:object_instance]))
          tab_class = tab_class.strip

          if active_tab && user_authorized_tab?(subtab) && user_can_access_tab?(subtab)
            tabs_html << self.render_tab((subtab[:options][:no_html_id] ? nil : subtab[:name]),
               subtab[:text],
               action_for_tab(subtab)[:url].merge!(:skip_relative_url_root => true),
               tab_class, subtab[:options][:link_text], last_dropdown, subtab[:options][:dropdown])

            last_dropdown = subtab[:options][:dropdown] if user_can_access_tab?(subtab)
          end
        end
      else
        tab[:tabs].each do |subtab|
          if user_can_access_tab?(subtab)
            unless object_instance && subtab[:options] && subtab[:options][:object_instance] && !(object_instance == subtab[:options][:object_instance])
              tabs_html = render_tabs(subtab, deep + 1, deep_level, tab_class_name, object_instance)
              return tabs_html unless tabs_html.empty?
            end
          end
        end
      end
      tabs_html
    end

    # This code could be better but works!
    def current_tab?(tab)
      if tab[:tabs].empty?
        return false if tab[:options] && tab[:options][:except] && controller.params[:controller] == tab[:url][:controller] && (tab[:options][:except].include? controller.params[:action])
        if tab[:url] && tab[:url][:action]
          return (controller.params[:controller] == tab[:url][:controller] &&
                     controller.params[:action] == tab[:url][:action]) ||
                     (in_clones?(tab, controller.params[:controller], controller.params[:action]))
        else
          return controller.params[:controller] == tab[:url][:controller] ||
                     (in_clones?(tab, controller.params[:controller], controller.params[:action]))
        end
      else
        tab[:tabs].each { |subtab| return true if current_tab?(subtab) }
      end
      false
    end
    
    def in_clones?(tab, controller, action)
      tab[:clones].each do |clon|
        return true if clon[:controller] == controller and (clon[:actions].blank? or clon[:actions].include? action)
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
      return nil if tab[:options] && tab[:options][:only] && (tab[:options][:only] & (current_user.roles.map{|r| r.name})).blank?
      return true unless controller.class.methods.include?("user_authorized_for?")
      tab[:tabs].each { |subtab| return true if user_authorized_tab?(subtab) } unless tab[:tabs].empty?

      if tab[:url][:action]
        return (tab[:url][:controller] + "_controller").camelize.constantize.user_authorized_for?(current_user, { :action => tab[:url][:action] }, binding)
      else
        return (tab[:url][:controller] + "_controller").camelize.constantize.user_authorized_for?(current_user, { :action => 'index' }, binding)
      end
    end

    def user_can_access_tab?(tab)
      tab[:url][:controller].classify.constantize.find(tab[:url][:id]).user_can_access?(current_user) rescue true
    end

    def render_tab(id, text, url, class_name, link_text, last_dd, current_dd)
      tab_html = ''
      if last_dd and !current_dd
        tab_html << close_dropdown
        tab_html << render_li(id, text, url, class_name, link_text)
      elsif last_dd and current_dd and last_dd != current_dd
        tab_html << close_dropdown
        tab_html << new_dropdown(current_dd)
        tab_html << render_li(id, text, url, class_name, link_text)
      elsif !last_dd and current_dd
        tab_html << new_dropdown(current_dd)
        tab_html << render_li(id, text, url, class_name, link_text)
      elsif (!last_dd and !current_dd) or (last_dd == current_dd)
        tab_html << render_li(id, text, url, class_name, link_text)
      end
      tab_html
    end

    def close_dropdown
      '</ul></li>'
    end

    def new_dropdown(title)
      "<li><span class='dir'>#{title}</span><ul class='dropdown'>"
    end

    def render_li(id, text, url, class_name, link_text)
      id ? content_tag("li", link_to((link_text.blank? ? t(text) : link_text), url), :id => id, :class => class_name) :
        content_tag("li", link_to((link_text.blank? ? t(text) : link_text), url), :class => class_name)
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
            self.clones << options
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
