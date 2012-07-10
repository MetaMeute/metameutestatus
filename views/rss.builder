xml.rss :version => "2.0" do  
  xml.channel do  
    xml.title "MetaMeuteStatus"
    xml.description "MetaMeuteStatus Feed"
    xml.link request.url

    @data.each do |d|  
      xml.item do  
        xml.title (d['door_open']=="1"?"open":"closed") + ": " + d['message'] + " (" + d['source'] + ")"
        xml.link "#{request.url.chomp request.path_info}"  
        xml.guid "#{request.url.chomp request.path_info}/#{d['id']}"  
        xml.pubDate Time.parse(d['timestamp'].to_s).rfc822  
        xml.description d['message']
      end  
    end  
  end  
end  
