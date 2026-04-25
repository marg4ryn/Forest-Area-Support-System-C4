workspace "System Wsparcia Terenów Leśnych" {
    model {

        # ── Actors ────────────────────────────────────────────────────────────
        tourist       = person "Turysta"
        underForester = person "Podleśniczy"
        forester      = person "Leśniczy"
        overForester  = person "Nadleśniczy"
        director      = person "Dyrektor"
        admin         = person "Administrator"

        # ──External systems ───────────────────────────────────────────────────
        mapsApi = softwareSystem "Mapy.com API" "Dane geolokalizacyjne"  {
            tags "External"
        }
        weatherApi = softwareSystem "Open-Meteo API" "Dane pogodowe"  {
            tags "External"
        }

        # ── Main system ────────────────────────────────────────────────────────
        forestSystem = softwareSystem "System Wsparcia Terenów Leśnych" {

            # Frontends
            publicWebApp = container "Public Web App" "Aplikacja dla turystów"  {
                tags "Frontend"
            }
            internalWebApp = container "Internal Web App" "Aplikacja dla pracowników" {
                tags "Frontend"
            }

            # API Gateways
            publicApiGateway = container "Public API Gateway" "Routing i weryfikacja JWT turysty"   {
                tags "API Gateway"
            }
            internalApiGateway = container "Internal API Gateway" "Routing i weryfikacja JWT pracownika" {
                tags "API Gateway"
            }

            # Auth Services
            touristAuthService  = container "Tourist Auth Service" "Rejestracja i aktywacja kont turystów."  {
                tags "Auth"
            }
            employeeAuthService = container "Employee Auth Service" "Rejestracja i aktywacja kont pracowników."  {
                tags "Auth"
            }

            # Domain services
            employeeService = container "Employee Service" "Dane pracowników, hierarchia. " 
            assignmentService = container "Assignment Service" "Przypisania pracowników do obszarów." 
            areaService = container "Area Service" "Hierarchia obszarów leśnych." 
            tripService = container "Trip Service" "Planowanie wycieczek, zarządzanie uczestnikami. Orkiestrator." 
            patrolService = container "Patrol Service" "Planowanie i realizacja patroli. Orkiestrator." 
            warningService = container "Warning Service" "Zarządzanie ostrzeżeniami. Auto-wygasanie." 
            notificationService = container "Notification Service" "Wysyłanie powiadomień." 

            mapGateway = container "Map Gateway" "Proxy Mapy.com API"  {
                tags "Domain Gateway"
            }
            weatherGateway = container "Weather Gateway" "Proxy Open-Meteo API" {
                tags "Domain Gateway"
            }

            # Event Bus
            eventBus = container "Event Bus" "Magistrala zdarzeń domenowych" "Kafka" {
                tags "Messaging"
            }
            
            # Database
            database = container "Database" "Współdzielona baza danych, w której każdy serwis posiada własne, prywatne tabele; dostęp realizowany bezpośrednio przez wszystkie serwisy" {
                tags "Database"
            }
        }

        # ── C1 Relationships ─────────────────────────────────────────────────────────
        tourist       -> forestSystem "Organizuje wycieczki"
        underForester -> forestSystem "Realizuje patrole, zgłasza ostrzeżenia"
        forester      -> forestSystem "Zarządza podleśniczymi i patrolami"
        overForester  -> forestSystem "Zarządza leśniczymi i leśnictwami"
        director      -> forestSystem "Zarządza nadleśniczymi i nadleśnictwami"
        admin         -> forestSystem "Zarządza systemem i użytkownikami"
        forestSystem  -> mapsApi      "Dane geolokalizacyjne" "REST"
        forestSystem  -> weatherApi   "Dane pogodowe" "REST"

        # ── C2 Relationships ─────────────────────────────────────────────────────────
        tourist       -> publicWebApp   "Organizuje wycieczki"
        underForester -> internalWebApp "Realizuje patrole, zgłasza ostrzeżenia"
        forester      -> internalWebApp "Zarządza podleśniczymi i patrolami"
        overForester  -> internalWebApp "Zarządza leśniczymi i leśnictwami"
        director      -> internalWebApp "Zarządza nadleśniczymi i nadleśnictwami"
        admin         -> internalWebApp "Zarządza systemem i użytkownikami"

        publicWebApp   -> publicApiGateway   "REST"
        internalWebApp -> internalApiGateway "REST"

        # Public Gateway
        publicApiGateway -> touristAuthService "Rejestracja, logowanie" "REST"
        publicApiGateway -> tripService        "Organizowanie wycieczek" "REST"
        publicApiGateway -> warningService     "Przeglądanie ostrzeżeń" "REST"
        publicApiGateway -> mapGateway         "Mapa" "REST"
        publicApiGateway -> weatherGateway     "Pogoda" "REST"

        # Internal Gateway
        internalApiGateway -> employeeAuthService "Rejestracja, logowanie" "REST"
        internalApiGateway -> employeeService     "Zarządzanie pracownikami" "REST"
        internalApiGateway -> assignmentService   "Zarządzanie przypisaniami" "REST"
        internalApiGateway -> areaService         "Zarządzanie obszarami" "REST"
        internalApiGateway -> patrolService       "Zarządzanie patrolami" "REST"
        internalApiGateway -> touristAuthService  "Zarządzanie turystami" "REST"
        internalApiGateway -> warningService      "Zgłaszanie i przeglądanie ostrzeżeń" "REST"
        internalApiGateway -> mapGateway          "Mapa" "REST"
        internalApiGateway -> weatherGateway      "Pogoda" "REST"

        # Event Bus — producers
        touristAuthService  -> eventBus "TouristRegistered" "Kafka"
        employeeService     -> eventBus "EmployeeProfileCreated" "Kafka"
        employeeAuthService -> eventBus "EmployeeActivationTokenCreated, EmployeeAccountActivated, EmployeeActivationExpired, EmployeeAccountDeleted" "Kafka"
        areaService         -> eventBus "AreaCreated, AreaDeleted" "Kafka"        
        assignmentService   -> eventBus "AssignmentCreated, AssignmentAccepted, AssignmentRejected, AssignmentReminderSent, AssignmentAutoAccepted, PatrolAssignmentValidated, PatrolAssignmentRejected" "Kafka"
        patrolService       -> eventBus "PatrolAssignmentValidationRequested, PatrolCreated, PatrolWarningNotificationRequired" "Kafka"
        warningService      -> eventBus "WarningCreated" "Kafka"
        tripService         -> eventBus "TripWarningNotificationRequired, ParticipantInvited, TripOrganizerAssigned, TripCancelled" "Kafka"

        # Event Bus — consumers
        eventBus -> employeeAuthService  "EmployeeProfileCreated, EmployeeAccountDeleted" "Kafka"
        eventBus -> employeeService      "EmployeeAccountActivated, EmployeeActivationExpired" "Kafka"
        eventBus -> patrolService        "AreaCreated, AreaDeleted, WarningCreated, PatrolAssignmentValidated, PatrolAssignmentRejected, EmployeeAccountDeleted" "Kafka"
        eventBus -> assignmentService    "PatrolAssignmentValidationRequested, EmployeeAccountDeleted" "Kafka"
        eventBus -> tripService          "WarningCreated" "Kafka"
        eventBus -> notificationService  "TouristRegistered, EmployeeActivationTokenCreated, AssignmentCreated, AssignmentAccepted, AssignmentRejected, AssignmentReminderSent, AssignmentAutoAccepted, PatrolCreated, PatrolWarningNotificationRequired, TripWarningNotificationRequired, ParticipantInvited, TripOrganizerAssigned, TripCancelled" "Kafka"

        # External integrations
        mapGateway     -> mapsApi    "REST"
        weatherGateway -> weatherApi "REST"
    }

    views {

        systemContext forestSystem "SystemContext" {
            include *
            autolayout lr
        }

        container forestSystem "ContainerDiagram" {
            include *
            autolayout lr
        }

        styles {
            element "Person" {
                shape Person
                background #2e7d32
                color #ffffff
            }
            element "Software System" {
                shape RoundedBox
                background #1565c0
                color #ffffff
            }
            element "Container" {
                shape RoundedBox
                background #1e88e5
                color #ffffff
            }
            element "Auth" {
                shape RoundedBox
                background #00838f
                color #ffffff
            }
            element "Frontend" {
                shape RoundedBox
                background #43a047
                color #ffffff
            }
            element "API Gateway" {
                shape Pipe
                background #6a1b9a
                color #ffffff
            }
            element "Domain Gateway" {
                shape RoundedBox
                background #ef6c00
                color #ffffff
            }
            element "Messaging" {
                shape Pipe
                background #ef1c00
                color #ffffff
            }
            element "Database" {
                shape Cylinder
                background #546e7a
                color #ffffff
            }
            element "External" {
                shape RoundedBox
                background #f9a825
                color #000000
            }
        }
    }

    configuration {
        scope softwaresystem
    }
}