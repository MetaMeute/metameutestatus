xml.instruct! :xml, :version=>"1.0", :encoding=>"utf-8"
xml.rss :version => "2.0" do  
  xml.channel do  
    xml.title "MetaMeuteStatus"
    xml.description "MetaMeuteStatus Feed"
    xml.link request.url

    @data.each do |d|  
      xml.item do  
        xml.title((d['door_open'].to_i==1?"open":"closed") + ": " + d['message'].to_s + " (" + h(d['source'].to_s) + ")")
        xml.link "#{request.url.chomp request.path_info}"  
        xml.guid "#{request.url.chomp request.path_info}/#{d['id']}"  
        xml.pubDate Time.parse(d['timestamp'].to_s + "UTC").rfc822
        xml.description h(d['message'].to_s)
      end  
    end  
  end  
end  
