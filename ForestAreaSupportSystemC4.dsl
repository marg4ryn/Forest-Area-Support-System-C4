workspace "System Wsparcia Terenów Leśnych" {
    model {

        # ── Actors ──────────────────────────────────────────────────────────────
        tourist       = person "Turysta"
        underForester = person "Podleśniczy"
        forester      = person "Leśniczy"
        overForester  = person "Nadleśniczy"
        director      = person "Dyrektor"
        admin         = person "Administrator"

        # ──External systems ─────────────────────────────────────────────────
        mapsApi = softwareSystem "Mapy.com API" "Dane geolokalizacyjne"  {
            tags "External"
        }
        weatherApi = softwareSystem "Open-Meteo API" "Dane pogodowe"  {
            tags "External"
        }

        # ── Main system ──────────────────────────────────────────────────────
        forestSystem = softwareSystem "System Wsparcia Terenów Leśnych" {

            # ── Frontends ──────────────────────────────────────────────────────
            publicWebApp = container "Public Web App" "Aplikacja turystyczna"  {
                tags "Frontend"
            }
            internalWebApp = container "Internal Web App" "Aplikacja pracownicza" {
                tags "Frontend"
            }

            # ── API Gateways ───────────────────────────────────────────────────
            publicApiGateway = container "Public API Gateway" "Routing i weryfikacja JWT turysty"   {
                tags "API Gateway"
            }
            internalApiGateway = container "Internal API Gateway" "Routing i weryfikacja JWT pracownika" {
                tags "API Gateway"
            }

            # ── Auth Services ──────────────────────────────────────────────────
            touristAuthService  = container "Tourist Auth Service" "Rejestracja i aktywacja kont turystów."  {
                tags "Auth"
            }
            employeeAuthService = container "Employee Auth Service" "Rtejestracja i aktywacja kont pracowników."  {
                tags "Auth"
            }

            # ── Domain services ───────────────────────────────────────────────
            employeeService = container "Employee Service" "Dane pracowników, hierarchia. " 
            assignmentService = container "Assignment Service" "Przypisania pracowników do obszarów." 
            areaService = container "Area Service" "Hierarchia obszarów leśnych." 
            tripService = container "Trip Service" "Planowanie wycieczek, zarządzanie uczestnikami. Orkiestrator." 
            patrolService = container "Patrol Service" "Planowanie i realizacja patroli. Orkiestrator." 
            warningService = container "Warning Service" "Zarządzanie ostrzeżeniami. Auto-wygasanie." 
            notificationService = container "Notification Service" "Wysyłanie powiadomień push/SMS/e-mail." 

            mapGateway = container "Map Gateway" "Proxy Mapy.com API"  {
                tags "Domain Gateway"
            }
            weatherGateway = container "Weather Gateway" "Proxy Open-Meteo API" {
                tags "Domain Gateway"
            }

            # ── Event Bus ──────────────────────────────────────────────────────
            eventBus = container "Event Bus" "Magistrala zdarzeń domenowych" "Kafka" {
                tags "Messaging"
            }
        }

        # ── C1 Relationships ─────────────────────────────────────────────────────────
        tourist       -> forestSystem "Organizuje wycieczki, przegląda mapy, otrzymuje ostrzeżenia"
        underForester -> forestSystem "Realizuje patrole, zgłasza ostrzeżenia"
        forester      -> forestSystem "Zarządza podleśniczymi i patrolami"
        overForester  -> forestSystem "Zarządza leśniczymi i leśnictwami"
        director      -> forestSystem "Zarządza nadleśniczymi i nadleśnictwami"
        admin         -> forestSystem "Zarządza systemem i kontami"
        forestSystem  -> mapsApi      "Dane geolokalizacyjne" "REST/HTTPS"
        forestSystem  -> weatherApi   "Dane pogodowe" "REST/HTTPS"

        # ── C2 Relationships ─────────────────────────────────────────────────────────

        tourist       -> publicWebApp   "Organizuje wycieczki, przegląda mapy, otrzymuje ostrzeżenia"
        underForester -> internalWebApp "Realizuje patrole, zgłasza ostrzeżenia"
        forester      -> internalWebApp "Zarządza podleśniczymi i patrolami"
        overForester  -> internalWebApp "Zarządza leśniczymi i leśnictwami"
        director      -> internalWebApp "Zarządza nadleśniczymi i nadleśnictwami"
        admin         -> internalWebApp "Zarządza systemem i kontami"

        publicWebApp   -> publicApiGateway   "HTTPS"
        internalWebApp -> internalApiGateway "HTTPS"

        # Public Gateway
        publicApiGateway -> touristAuthService "Rejestracja, logowanie, aktywacja kont" "REST"
        publicApiGateway -> tripService        "Organizowanie wycieczek" "REST"
        publicApiGateway -> warningService     "Przeglądanie ostrzeżeń" "REST"
        publicApiGateway -> mapGateway         "Mapa" "REST"
        publicApiGateway -> weatherGateway     "Pogoda" "REST"

        # Internal Gateway
        internalApiGateway -> employeeAuthService "Logowanie, aktywacja kont" "REST"
        internalApiGateway -> employeeService     "Zarządzanie pracownikami" "REST"
        internalApiGateway -> assignmentService   "Zarządzanie przypisaniami" "REST"
        internalApiGateway -> areaService         "Zarządzanie obszarami" "REST"
        internalApiGateway -> patrolService       "Zarządzanie patrolami" "REST"
        internalApiGateway -> touristAuthService  "Zarządzanie turystami" "REST"
        internalApiGateway -> warningService      "Zgłaszanie ostrzeżeń" "REST"
        internalApiGateway -> mapGateway          "Mapa" "REST"
        internalApiGateway -> weatherGateway      "Pogoda" "REST"

        # Internal Orchestration - Trip Service
        tripService -> mapGateway "Wyznaczanie i walidacja trasy" "REST"

        # Internal Orchestration — Patrol Service
        patrolService -> mapGateway       "Wyznaczanie trasy" "REST"
        patrolService -> areaService      "Walidacja granic obszaru" "REST"
        patrolService -> assignmentService "Weryfikacja przypisań" "REST"

        # Event Bus — producers
        touristAuthService  -> eventBus "TouristRegistered" "Kafka"
        employeeService     -> eventBus "EmployeeCreated, EmployeeDeleted" "Kafka"
        employeeAuthService -> eventBus "EmployeeInvitationSent, EmployeeActivated, AccountExpired, AccountDeactivated, DirectorRoleTransferred" "Kafka"
        assignmentService   -> eventBus "AssignmentCreated, AssignmentAccepted, AssignmentRejected, AssignmentExpired" "Kafka"
        patrolService       -> eventBus "PatrolCreated, PatrolDone" "Kafka"
        warningService      -> eventBus "WarningCreated, WarningExpired, WarningDeleted" "Kafka"
        tripService         -> eventBus "TripInvitationSent, TripCancelled" "Kafka"

        # Event Bus — consumers
        eventBus -> employeeAuthService  "EmployeeCreated" "Kafka"
        eventBus -> employeeService      "EmployeeActivated" "Kafka"
        eventBus -> notificationService  "TouristRegistered, EmployeeInvitationSent, AssignmentCreated, AssignmentAccepted, AssignmentRejected, PatrolCreated, WarningCreated" "Kafka"
        eventBus -> warningService       "PatrolDone" "Kafka"

        # External integrations
        mapGateway     -> mapsApi    "REST/HTTPS"
        weatherGateway -> weatherApi "REST/HTTPS"
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
                shape Cylinder
                background #6a1b9a
                color #ffffff
            }
            element "Domain Gateway" {
                shape RoundedBox
                background #ef6c00
                color #ffffff
            }
            element "Messaging" {
                shape Cylinder
                background #ef1c00
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
