workspace "System Wsparcia Terenów Leśnych" "System zarządzania terenami leśnymi, patrolami i ostrzeżeniami" {
    model {

        # Osoby
        tourist = person "Turysta" "Planuje wycieczki, przegląda mapy i otrzymuje ostrzeżenia"
        underForester = person "Podleśniczy" "Realizuje patrole, zgłasza ostrzeżenia"
        forester = person "Leśniczy" "Zarządza podleśniczymi i patrolami"
        overForester = person "Nadleśniczy" "Zarządza leśnictwami i leśniczymi"
        director = person "Dyrektor" "Zarządza nadleśnictwami"
        admin = person "Administrator" "Zarządza systemem i użytkownikami"

        # System główny + kontenery
        forestSystem = softwareSystem "System Wsparcia Terenów Leśnych" "Umożliwia zarządzanie obszarami leśnymi, patrolami, wycieczkami oraz ostrzeżeniami" {

            webApp = container "Web Application" "Frontend dla użytkowników" "HTML/CSS/JS"

            authService = container "Auth Service" "Logowanie, rejestracja, role" "FastAPI"
            personnelService = container "Personnel Service" "Zarządzanie pracownikami i przypisaniami" "FastAPI"
            areaService = container "Area Service" "Zarządzanie obszarami leśnymi" "FastAPI"
            tripService = container "Trip Service" "Planowanie wycieczek" "FastAPI"
            patrolService = container "Patrol Service" "Planowanie patroli" "FastAPI"
            warningService = container "Warning Service" "Zarządzanie ostrzeżeniami" "FastAPI"
            notificationService = container "Notification Service" "Wysyłanie powiadomień" "FastAPI"
            mapGateway = container "Map Gateway" "Integracja z mapami" "FastAPI"
            weatherGateway = container "Weather Gateway" "Integracja z pogodą" "FastAPI"

            messageBroker = container "Message Broker" "Kolejki komunikatów" "RabbitMQ"
        }

        # Systemy zewnętrzne
        mapsApi = softwareSystem "Mapy.com API" "Dostarcza mapy i wyznacza trasy" {
            tags "External"
        }

        weatherApi = softwareSystem "Open-Meteo API" "Dostarcza dane pogodowe" {
            tags "External"
        }

        # Relacje użytkowników (C1 + C2)
        tourist -> forestSystem "Używa do planowania wycieczek i sprawdzania pogody"
        tourist -> forestSystem "Otrzymuje ostrzeżenia"

        underForester -> forestSystem "Zgłasza ostrzeżenia i realizuje patrole"
        forester -> forestSystem "Zarządza patrolami i personelem"
        overForester -> forestSystem "Zarządza strukturą organizacyjną"
        director -> forestSystem "Zarządza nadleśnictwami"
        admin -> forestSystem "Administruje systemem"

        # Frontend
        tourist -> webApp "Korzysta"
        underForester -> webApp "Korzysta"
        forester -> webApp "Korzysta"
        overForester -> webApp "Korzysta"
        director -> webApp "Korzysta"
        admin -> webApp "Korzysta"

        # Frontend -> mikroserwisy
        webApp -> authService "REST"
        webApp -> personnelService "REST"
        webApp -> areaService "REST"
        webApp -> tripService "REST"
        webApp -> patrolService "REST"
        webApp -> warningService "REST"

        # Kolejki (choreografia)
        warningService -> messageBroker "Publikuje zdarzenia"
        messageBroker -> notificationService "Konsumuje zdarzenia"

        tripService -> messageBroker
        patrolService -> messageBroker

        # Integracje
        tripService -> mapGateway "Pobiera trasy"
        patrolService -> mapGateway "Pobiera trasy"
        mapGateway -> mapsApi "REST/HTTPS"

        tripService -> weatherGateway "Pobiera pogodę"
        patrolService -> weatherGateway "Pobiera pogodę"
        weatherGateway -> weatherApi "REST/HTTPS"
        warningService -> mapGateway "Pobiera mapę dla użytkownika"
    }

    views {

        # C1
        systemContext forestSystem "SystemContext" {
            include *
            autolayout lr
        }

        # C2
        container forestSystem "ContainerDiagram" {
            include *
            autolayout lr
        }

        styles {
            element "Person" {
                shape person
                color #55cc55
            }
            element "Software System" {
                shape RoundedBox
                color #0000ff
            }
            element "Container" {
                shape RoundedBox
            }
            element "External" {
                color #dd9900
            }
        }
    }

    configuration {
        scope softwaresystem
    }
}