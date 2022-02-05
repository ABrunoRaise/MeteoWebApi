defmodule MeteoWebApi do

  # HTTPoison.get!("https://api.github.com")
  # pid = spawn(MeteoWebApi,:main,[[]])
  # send(pid, {:start,"london"})

  def main(_args) do
    ioPutsPid = spawn(MeteoWebApi, :ioPuts, [self()])
    ioGetPid = spawn(MeteoWebApi, :ioGet, [self()])
    cityManagerPid = spawn(MeteoWebApi, :cityManager, [%{},self()])
    send(ioPutsPid, {:welcomeMessage})
    receiver(ioGetPid,cityManagerPid,ioPutsPid)
  end

  def receiver(ioGetPid, cityManagerPid, ioPutsPid) do
    receive do
      #ioPut destination
      {:help} ->
        send(ioPutsPid, {:help})
      {:wrongCommand} ->
        send(ioPutsPid, {:wrongCommand})
      {:ok,response} -> 
        send(ioPutsPid, {:ok, response})
      {:error,response} -> 
        send(ioPutsPid, {:ok, response})    
      {:ok,:cityList, cityList} ->
        send(ioPutsPid, {:ok,:cityList,cityList})
      #ioGet destination
      {:newCommand} ->
        send(ioGetPid,{:newCommand})
      #cityManager destination
      {:add, cityName} ->
        send(cityManagerPid,{:add, cityName})
      {:fetch, cityName} ->
        send(cityManagerPid,{:fetch, cityName})
      {:remove, cityName} ->
        send(cityManagerPid,{:remove, cityName})
      {:cityList} ->
        send(cityManagerPid,{:cityList})
    end
    receiver(ioGetPid, cityManagerPid, ioPutsPid)
  end

  def ioGet(mainPid) do
    receive do
      {:newCommand} ->
        command = IO.gets("> ") |> String.trim()
        case command do 
          "!help" -> 
            send(mainPid,{:help})
          "!start " <> cityName ->
            send(mainPid,{:add, cityName})
          "!remove " <> cityName ->
            send(mainPid,{:remove, cityName})
          "!fetch " <> cityName ->
            send(mainPid,{:fetch, cityName})
          "!cityList" ->
            send(mainPid,{:cityList})
          _ -> 
            send(mainPid, {:wrongCommand})
        end
        ioGet(mainPid)  
    end
  end

  def ioPuts(mainPid) do
    receive do
      {:welcomeMessage} ->
        IO.puts("Welcome to the new meteo app. Write !help for the command list")   
      {:wrongCommand} ->
        IO.puts("Wrong syntax. Write !help for the command list")   
      {:help} -> 
        IO.puts("!cityList -> List all available city")
        IO.puts("!start {cityname} -> Start a new city analysis")
        IO.puts("!fetch {cityname}/all -> Fetch city information or all city information")
        IO.puts("!remove {cityname}/all -> Remove city information or all city information")
      {:ok, :cityList, cityList} ->
        IO.inspect(cityList)
      #Accorpare questi   
      {:ok, response} ->
        IO.puts(response)
      {:error, response} ->
        IO.puts(response)
    end
    send(mainPid,{:newCommand})
    ioPuts(mainPid)
  end

  def weather(city, senderPid) do
    receive do
      :fetch -> 
        resp = HTTPoison.get!("https://wttr.in/#{city}?format=%22%l:%t%22").body
        send(senderPid, {:fetch, resp})
        weather(city, senderPid)
      :remove ->
        send(senderPid, {:remove, "Removed city #{city}"})
    end
  end

  def cityManager(cityMap, mainPid) do
    receive do
      {:remove, city} ->
        process = cityMap[city]
        if process != nil do
          send(process,:remove)
          receive do 
          {:remove, response} -> 
            send(mainPid,{:ok, response})
            cityManager(Map.delete(cityMap,city),mainPid)
          end
        else
          send(mainPid,{:error, "City #{city} not available"})  #codice 
          cityManager(cityMap,mainPid)
        end
      {:add, city} -> 
        process = spawn(MeteoWebApi, :weather,[city, self()])
        send(process, :fetch)
        receive do 
          {:fetch, response} -> 
            send(mainPid,{:ok, response})
            cityManager(Map.put(cityMap,city, process),mainPid)
        end
      {:fetch, city} ->
        process = cityMap[city]
        if process != nil do
          send(process,:fetch)
          receive do 
          {:fetch, response} -> 
            send(mainPid,{:ok, response})
          end
        else
          send(mainPid,{:error, "City #{city} not available"}) #codice 
        end
          cityManager(cityMap,mainPid)
      {:cityList} ->
        send(mainPid,{:ok,:cityList,Map.keys(cityMap)})
        cityManager(cityMap,mainPid)
    end
  end
end


#TODO refresh, refresh single city, try and catch in fetch, link per error 