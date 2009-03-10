# 
# redcloth_scan.rb.rl
# 
# Copyright (C) 2009 Jason Garber
# 


%%{

  machine redcloth_scan;
  include redcloth_common "redcloth_common.rb.rl";

  action extend { extend = regs["type"] }

  include redcloth_scan "redcloth_scan.rl";

}%%

module RedCloth
  module BaseScanner
    attr_accessor :p, :pe, :refs
    attr_accessor :data, :orig_data, :cs, :act, :nest, :ts, :te, :reg, :bck, :eof,
      :html, :table, :block, :regs
    attr_accessor :list_layout, :list_type, :list_index, :list_continue, :listm, 
      :refs_found, :plain_block

    def CLEAR_REGS()
      self.regs = {}
    end
    def RESET_REG()
      reg = nil
    end
    def CAT(h)
      return if h.empty? #FIXME WHY WOULD IT BE BLANK?
      h << data[ts, te-ts]
    end
    def CLEAR(h)
      h = ""
    end
    def RSTRIP_BANG(h)
      h.rstrip!
    end
    def SET_PLAIN_BLOCK(t) 
      plain_block = t
    end
    def RESET_TYPE()
      self.regs[:type] = plain_block
    end
    def INLINE(h, t)
      h << self.send(t, regs)
    end
    def DONE(h)
      html << h
      CLEAR(h)
      CLEAR_REGS()
    end
    def PASS(h, a, t)
      h << red_pass(regs, a.to_sym, t, refs)
    end
    def PARSE_ATTR(a)
      red_parse_attr(regs, a)
    end
    def PARSE_LINK_ATTR(a)
      red_parse_link_attr(regs, a)
    end
    def PARSE_IMAGE_ATTR(a)
      red_parse_image_attr(regs, a)
    end
    def PASS_CODE(h, a, t, o)
      h << red_pass_code(regs, a, t)
    end
    def ADD_BLOCK()
      html << red_block(regs, block, refs)
      @extend = nil
      CLEAR(block)
      CLEAR_REGS()
    end
    def ADD_EXTENDED_BLOCK()
      html << red_block(regs, block, refs)
      CLEAR(@block)
    end
    def END_EXTENDED()
      @extend = nil
      CLEAR_REGS()
    end
    def ADD_BLOCKCODE()
      html << red_blockcode(regs, block)
      CLEAR(@block)
      CLEAR_REGS()
    end
    def ADD_EXTENDED_BLOCKCODE()
      html << red_blockcode(regs, block)
      CLEAR(block)
    end
    def ASET(t, v)
      regs[t] = v
    end
    def AINC(t)
      red_inc(regs, t)
    end
    def INC(n)
      n += 1
    end
    def SET_ATTRIBUTES()
      SET_ATTRIBUTE("class_buf", "class")
      SET_ATTRIBUTE("id_buf", "id")
      SET_ATTRIBUTE("lang_buf", "lang")
      SET_ATTRIBUTE("style_buf", "style")
    end
    def SET_ATTRIBUTE(b, a)
      regs[a] = regs[b] unless regs[b].nil?
    end
    def TRANSFORM(t)
      if (p > reg && reg >= ts)
        str = redcloth_transform(reg, p, refs)
        regs[t] = str
        # /*printf("TRANSFORM(" T ") '%s' (p:'%s' reg:'%s')\n", RSTRING_PTR(str), p, reg);*/  \
      else
        regs[t] = nil
      end
    end
    def STORE(t)
      if (p > reg && reg >= ts)
        str = data[reg, p-reg]
        regs[t] = str
        # /*printf("STORE(" T ") '%s' (p:'%s' reg:'%s')\n", RSTRING_PTR(str), p, reg);*/  \
      else
        regs[t] = nil
      end
    end
    def STORE_B(t)
      if (p > bck && bck >= ts)
        str = data[bck, p-bck]
        regs[t] = str
        # /*printf("STORE_B(" T ") '%s' (p:'%s' reg:'%s')\n", RSTRING_PTR(str), p, reg);*/  \
      else
        regs[t] = nil
      end
    end
    def STORE_URL(t)
      if (p > reg && reg >= ts)
        punct = true
        while (p > reg && punct)
          case data[p - 1, 1]
          when ')'
            temp_p = p - 1
            level = -1
            while (temp_p > reg)
              case data[temp_p - 1, 1]
                when '('; level += 1
                when ')'; level -= 1
              end
              temp_p -= 1
            end
            if (level == 0) 
              punct = 0
            else
              p -= 1
            end
          when '!', '"', '#', '$', '%', ']', '[', '&', '\'',
            '*', '+', ',', '-', '.', '(', ':', ';', '=', 
            '?', '@', '\\', '^', '_', '`', '|', '~'
              p -= 1
          else
            punct = 0
          end
        end
        te = p
      end
      STORE(t)
      if ( !refs.nil? && refs.has_key?(regs[t]) )
        regs[t] = refs[regs[t]]
      end
    end
    def STORE_LINK_ALIAS()
      refs_found[regs[:text]] = regs[:href]
    end
    def CLEAR_LIST()
      list_layout = []
    end
    def LIST_ITEM()
      aint = 0
      aval = list_index[nest-1]
      aint = aval.to_i unless aval.nil?
      if (list_type == "ol")
        list_index[nest-1] = aint + 1
      end
      if (nest > list_layout.length)
        listm = sprintf("%s_open", list_type)
        if (list_continue)
          list_continue = false
          regs[:start] = list_index[nest-1]
        else
          start = regs[:start]
          if (start.nil?)
            list_index[nest-1] = 1
          else
            start_num = start.to_i
            list_index[nest-1] = start_num
          end
        end
        regs[:nest] = nest
        html << self.send(listm, regs)
        list_layout[nest-1] = list_type
        CLEAR_REGS()
        ASET("first", "true")
      end
      LIST_CLOSE()
      regs[:nest] = list_layout.length
      ASET("type", "li_open")
    end
    def LIST_CLOSE()
      while (nest < list_layout.length)
        regs[:nest] = list_layout.length
        end_list = list_layout.pop
        if (!end_list.nil?)
          listm = sprintf("%s_close", end_list)
          html << self.send(listm, regs)
        end
      end
    end

    def red_pass(regs, ref, meth, refs)
      txt = regs[ref]
      regs[ref] = redcloth_inline2(self, txt, refs) if (!txt.nil?)
      return self.send(meth, regs)
    end

    def red_inc(regs, ref)
      aint = 0
      aval = regs[ref]
      aint = aval.to_i if (!aval.nil?)
      regs[ref] = aint + 1
    end

    def red_block(regs, block, refs)
      sym_text = :text
      btype = regs[:type]
      block = block.strip
      if (!block.nil? && !btype.nil?)
        method = btype.intern
        if (method == :notextile)
          regs[sym_text] = block
        else
          regs[sym_text] = redcloth_inline2(block, refs)
        end
        if (self.formatter_methods.includes? method)
          block = self.send(method, regs)
        else
          fallback = regs[:fallback]
          if (!fallback.nil?)
            fallback << regs[sym_text]
            CLEAR_REGS()
            regs[sym_text] = fallback
          end
          block = self.p(regs);
        end
      end
      return block
    end

    def red_blockcode(regs, block)
      btype = regs[:type]
      if (block.length > 0)
        regs[:text] = block
        block = self.send(btype, regs)
      end
      return block
    end

    def rb_str_cat_escaped(str, ts, te)
      source_str = STR_NEW(ts, te-ts);
      escaped_str = self.escape(source_str)
      str << escaped_str
    end

    def rb_str_cat_escaped_for_preformatted(str, ts, te)
      source_str = STR_NEW(ts, te-ts);
      escaped_str = self.escape_pre(source_str)
      str << escaped_str
    end
    
  end
  
  module RedclothScan
    include BaseScanner
    
    def transform(data, refs)
      %% write data nofinal;
      # % (gets syntax highlighting working again)
      
      @data = data
      @refs = refs
      orig_data = data.dup
      nest = 0
      html = ""
      table = ""
      block = ""
      CLEAR_REGS()
      
      list_layout = nil
      list_index = [];
      list_continue = false;
      SET_PLAIN_BLOCK("p")
      extend = nil
      listm = []
      refs_found = {}
      
      %% write init;
      
      %% write exec;

      ADD_BLOCK() if (block.length > 0)

      if ( refs.nil? && !refs_found.empty? )
        return redcloth_transform(orig_data, refs_found)
      else
        after_transform(html)
        return html
      end
    end
  end
  
  class TextileDoc < String
    def to(formatter)
      self.delete!("\r")
      working_copy = self.clone
      working_copy.extend(formatter)
      
      if (working_copy.lite_mode)
        return working_copy.redcloth_inline2(self, {})
      else
        return working_copy.redcloth_transform2(self)
      end
    end
    
    class ParseError < Exception; end
    
    def redcloth_transform(data, refs)
      return self.extend(RedCloth::RedclothScan).transform(data, refs)
    end
    
    def redcloth_transform2(str)
      before_transform(str)
      return redcloth_transform(str, nil);
    end
    
    def redcloth_inline2(str)
      return self.extend(RedCloth::RedClothInline).redcloth_inline2(str, refs)
    end
    
    def html_esc(str, level=nil)
      return "" if str.nil? || str.empty?

      str.gsub!('&') { amp({}) }
      str.gsub!('>') { gt({}) }
      str.gsub!('<') { lt({}) }
      if (level != :html_escape_preformatted)
        str.gsub!("\n") { br({}) }
        str.gsub!('"') { quot({}) }
        str.gsub!("'") { level == :html_escape_attributes ? apos({}) : squot({}) }
      end
      return str;
    end
    
    def latex_esc(str)
      return "" if str.nil? || str.empty?
      
      str.gsub!('{') { entity({:text => "#123"}) }
      str.gsub!('}') { entity({:text => "#125"}) }
      str.gsub!('\\') { entity({:text => "#92"}) }
      str.gsub!('#') { entity({:text => "#35"}) }
      str.gsub!('$') { entity({:text => "#36"}) }
      str.gsub!('%') { entity({:text => "#37"}) }
      str.gsub!('&') { entity({:text => "amp"}) }
      str.gsub!('_') { entity({:text => "#95"}) }
      str.gsub!('^') { entity({:text => "circ"}) }
      str.gsub!('~') { entity({:text => "tilde"}) }
      str.gsub!('<') { entity({:text => "lt"}) }
      str.gsub!('>') { entity({:text => "gt"}) }
      str.gsub!('\n') { entity({:text => "#10"}) }
      
      return str
    end
    
    
    def STR_NEW(p,n) 
#FIXME      rb_enc_str_new((p),(n),rb_utf8_encoding())
    end
    
  end
end