workspace "System Wsparcia Terenów Leśnych" "System zarządzania terenami leśnymi, patrolami i ostrzeżeniami" {
    model {

        # ── Osoby ──────────────────────────────────────────────────────────────
        tourist       = person "Turysta"       "Organizuje wycieczki, przegląda mapy, otrzymuje ostrzeżenia"
        underForester = person "Podleśniczy"   "Realizuje patrole, zgłasza ostrzeżenia"
        forester      = person "Leśniczy"      "Zarządza podleśniczymi i patrolami"
        overForester  = person "Nadleśniczy"   "Zarządza leśniczymi, tworzy/usuwa leśnictwa"
        director      = person "Dyrektor"      "Zarządza nadleśniczymi, tworzy/usuwa nadleśnictwa"
        admin         = person "Administrator" "Zarządza systemem i kontami użytkowników"

        # ── Systemy zewnętrzne ─────────────────────────────────────────────────
        mapsApi    = softwareSystem "Mapy.com API"    "Przeglądanie mapy, wyznaczanie tras"
        weatherApi = softwareSystem "Open-Meteo API" "Dane pogodowe"

        # ── System główny ──────────────────────────────────────────────────────
        forestSystem = softwareSystem "System Wsparcia Terenów Leśnych" "Zarządzanie obszarami leśnymi, patrolami, wycieczkami i ostrzeżeniami" {

            # ── Frontendy ──────────────────────────────────────────────────────
            publicWebApp   = container "Public Web App"   "Aplikacja turystyczna: mapa, wycieczki, ostrzeżenia, pogoda" "React"
            internalWebApp = container "Internal Web App" "Aplikacja pracownicza: patrole, ostrzeżenia, zarządzanie jednostkami" "React"

            # ── API Gateways ───────────────────────────────────────────────────
            publicApiGateway   = container "Public API Gateway"   "Routing, rate-limiting, weryfikacja JWT turysty" "Kong"
            internalApiGateway = container "Internal API Gateway" "Routing, RBAC, weryfikacja JWT pracownika" "Kong"

            # ── Auth Services (rozdzielone) ────────────────────────────────────
            touristAuthService  = container "Tourist Auth Service"  "Rejestracja turystów (FR-04), logowanie (FR-05), zarządzanie sesją. Schema: tourist_users, tourist_sessions." "FastAPI"
            employeeAuthService = container "Employee Auth Service" "Tworzenie kont pracowniczych (FR-11), logowanie (FR-05, FR-26), RBAC hierarchiczny (NF-01, NF-02), dezaktywacja kont (FR-27), przekazanie roli dyrektora (FR-25). Schema: employee_users, roles, permissions." "FastAPI"

            # ── Serwisy domenowe ───────────────────────────────────────────────
            personnelService = container "Personnel Service" "Zarządzanie hierarchią pracowników i przypisaniami do jednostek (FR-16,19,20,23,24). CQRS. Schema: personnel_event_store, personnel_read. Zdarzenia: EmployeeAssignedToUnit, EmployeeRemovedFromUnit." "FastAPI"
            
            areaService = container "Area Service" "Zarządzanie hierarchią obszarów leśnych (FR-17,18,21,22). Agregat: ForestArea. Event Sourcing + CQRS. Schema: areas_event_store, areas_read. Zdarzenia wewnętrzne: ForestryCreated, ForestryDeleted, ForestDistrictCreated, ForestDistrictDeleted." "FastAPI"
            
            tripService = container "Trip Service" "Planowanie wycieczek i zarządzanie uczestnikami (FR-06,07,08,09). Agregat: Trip. Event Sourcing + CQRS. Schema: trips_event_store, trips_read. Zdarzenia wewnętrzne: TripCreated, TripRouteSet, TripCancelled, TripInvitationAccepted, TripInvitationRejected, TripParticipantRemoved. Zdarzenia na Event Bus: TripInvitationSent." "FastAPI"
            
            patrolService = container "Patrol Service" "Planowanie i realizacja patroli (FR-13,14). Agregat: Patrol. Event Sourcing + CQRS. Schema: patrols_event_store, patrols_read. Zdarzenia wewnętrzne: PatrolCreated, PatrolRouteSet, PatrolAborted. Zdarzenia na Event Bus: PatrolEmployeeAssigned, PatrolStarted, PatrolCompleted." "FastAPI"
            
            warningService = container "Warning Service" "Tworzenie i usuwanie ostrzeżeń (FR-03,12). Agregat: Warning. Event Sourcing + CQRS. Schema: warnings_event_store, warnings_read. Zdarzenia wewnętrzne: WarningResolved, WarningDeleted. Zdarzenia na Event Bus: WarningIssued, WarningEscalated." "FastAPI"
            
            notificationService = container "Notification Service" "Wysyłanie powiadomień push/SMS/e-mail (FR-10,15). Wyłącznie konsument Event Bus. Schema: notification_log. Subskrybuje: WarningIssued (push ≤60s, NF-06), WarningEscalated (SMS), TripInvitationSent (push), PatrolEmployeeAssigned (push)." "FastAPI"
            
            mapGateway     = container "Map Gateway"     "Proxy do Mapy.com API. Cache w Integration Cache. Brak domeny własnej." "FastAPI"
            weatherGateway = container "Weather Gateway" "Proxy do Open-Meteo API. Cache TTL=10min (NF-04). Brak domeny własnej." "FastAPI"

            # ── Saga Orchestratorzy ────────────────────────────────────────────
            tripSagaOrchestrator   = container "Trip Plan Saga"         "Orkiestruje tworzenie wycieczki: Area → Map → Weather → Trip. Kompensata: TripCancelled. Stan: schema_saga_state." "FastAPI"
            patrolSagaOrchestrator = container "Patrol Execution Saga"  "Orkiestruje planowanie patrolu: Area → Personnel → Map → Patrol. Kompensata: PatrolAborted. Stan: schema_saga_state." "FastAPI"

            # ── Event Bus ──────────────────────────────────────────────────────
            # Przepływy choreografii:
            #   WarningIssued        → Notification Service: push do turystów na trasie + pracownicy na patrolu (≤60s, NF-06)
            #   WarningEscalated     → Notification Service: SMS do leśniczego obszaru
            #   PatrolCompleted      → Warning Service: auto-resolve powiązanego Warning
            #                       → Personnel Service: aktualizacja historii patroli pracownika
            #   TripInvitationSent   → Notification Service: push z zaproszeniem (FR-07)
            #   PatrolEmployeeAssigned → Notification Service: push z przydziałem patrolu (FR-14)
            #   EmployeeAccountCreated → Personnel Service: inicjalizacja rekordu pracownika
            #   TouristRegistered    → (rozszerzenie: e-mail powitalny)

            eventBus = container "Event Bus" "Magistrala zdarzeń domenowych. At-least-once delivery, trwałe kolejki, replay zdarzeń, DLQ." "Kafka"

            # ── Bazy danych ────────────────────────────────────────────────────
            database = container "PostgreSQL" "Izolowane schematy per serwis. Serwisy z Event Sourcing posiadają event_store + read (projekcja). Schematy: tourist_auth, employee_auth, personnel (event_store + read), area (event_store + read), trips (event_store + read), patrols (event_store + read), warnings (event_store + read), notifications, saga_state." "PostgreSQL 16"

            # ── Cache — trzy oddzielne instancje ──────────────────────────────
            # Session Cache:     JWT, blacklista tokenów. TTL: minuty. Polityka: allkeys-lru.
            # Read Model Cache:  Projekcje CQRS. Zawiera też projekcję aktywnych tras wycieczek
            #                    odczytywaną przez Notification Service przy obsłudze WarningIssued (NF-06).
            # Integration Cache: Odpowiedzi zewnętrznych API. TTL: 10 min (NF-04). Polityka: volatile-ttl.

            sessionCache     = container "Session Cache"     "Sesje JWT turystów i pracowników, blacklista tokenów. TTL: minuty." "Redis"
            readModelCache   = container "Read Model Cache"  "Projekcje CQRS: wycieczki, patrole, ostrzeżenia, obszary. Projekcja aktywnych tras wycieczek dla Notification Service (NF-06)." "Redis"
            integrationCache = container "Integration Cache" "Cache odpowiedzi Map Gateway i Weather Gateway. TTL: 10 min (NF-04)." "Redis"
        }

        # ── Relacje C1 ─────────────────────────────────────────────────────────
        tourist       -> forestSystem "Planuje wycieczki, sprawdza mapę i ostrzeżenia"
        underForester -> forestSystem "Realizuje patrole, zgłasza ostrzeżenia"
        forester      -> forestSystem "Zarządza patrolami i personelem"
        overForester  -> forestSystem "Zarządza strukturą organizacyjną"
        director      -> forestSystem "Zarządza nadleśnictwami"
        admin         -> forestSystem "Administruje systemem"
        forestSystem  -> mapsApi    "Pobiera mapy i trasy" "REST/HTTPS"
        forestSystem  -> weatherApi "Pobiera dane pogodowe" "REST/HTTPS"

        # ── Relacje C2 ─────────────────────────────────────────────────────────

        tourist       -> publicWebApp
        underForester -> internalWebApp
        forester      -> internalWebApp
        overForester  -> internalWebApp
        director      -> internalWebApp
        admin         -> internalWebApp

        publicWebApp   -> publicApiGateway   "HTTPS"
        internalWebApp -> internalApiGateway "HTTPS"

        # Public Gateway
        publicApiGateway -> touristAuthService "Rejestracja i logowanie turysty (FR-04, FR-05)" "REST"
        publicApiGateway -> tripService        "Wycieczki read + command (FR-06,07,08,09)" "REST"
        publicApiGateway -> warningService     "Przeglądanie ostrzeżeń (FR-03)" "REST"
        publicApiGateway -> areaService        "Przeglądanie obszarów (FR-01)" "REST"
        publicApiGateway -> mapGateway         "Mapa dla turysty (FR-01)" "REST"
        publicApiGateway -> weatherGateway     "Pogoda dla turysty (FR-02)" "REST"

        # Internal Gateway
        internalApiGateway -> employeeAuthService "Logowanie, konta pracownicze (FR-05,11,25,26,27)" "REST"
        internalApiGateway -> personnelService    "Zarządzanie personelem (FR-16,19,20,23,24)" "REST"
        internalApiGateway -> areaService         "Zarządzanie obszarami (FR-17,18,21,22)" "REST"
        internalApiGateway -> patrolService       "Patrole read + command (FR-13,14)" "REST"
        internalApiGateway -> warningService      "Zgłaszanie ostrzeżeń (FR-12)" "REST"
        internalApiGateway -> mapGateway          "Mapa dla pracownika (FR-01)" "REST"
        internalApiGateway -> weatherGateway      "Pogoda dla pracownika (FR-02)" "REST"

        # Saga Orchestratorzy
        tripService            -> tripSagaOrchestrator   "Inicjuje TripPlanSaga po CreateTrip" "Async"
        patrolService          -> patrolSagaOrchestrator "Inicjuje PatrolSaga po SchedulePatrol" "Async"

        tripSagaOrchestrator   -> areaService    "Weryfikacja obszaru" "REST"
        tripSagaOrchestrator   -> mapGateway     "Pobieranie trasy" "REST"
        tripSagaOrchestrator   -> weatherGateway "Warunki pogodowe" "REST"
        tripSagaOrchestrator   -> tripService    "Zatwierdzenie lub TripCancelled" "REST"

        patrolSagaOrchestrator -> areaService      "Weryfikacja obszaru" "REST"
        patrolSagaOrchestrator -> personnelService "Dostępność pracownika" "REST"
        patrolSagaOrchestrator -> mapGateway       "Pobieranie trasy" "REST"
        patrolSagaOrchestrator -> patrolService    "Zatwierdzenie lub PatrolAborted" "REST"

        # Event Bus — producenci
        warningService      -> eventBus "WarningIssued, WarningEscalated" "Kafka"
        patrolService       -> eventBus "PatrolEmployeeAssigned, PatrolStarted, PatrolCompleted" "Kafka"
        tripService         -> eventBus "TripInvitationSent" "Kafka"
        touristAuthService  -> eventBus "TouristRegistered" "Kafka"
        employeeAuthService -> eventBus "EmployeeAccountCreated, UserAccountDeactivated, DirectorRoleTransferred" "Kafka"

        # Event Bus — konsumenci
        eventBus -> notificationService "WarningIssued → push ≤60s (NF-06), WarningEscalated → SMS, TripInvitationSent → push, PatrolEmployeeAssigned → push" "Kafka"
        eventBus -> warningService      "PatrolCompleted → auto-resolve Warning" "Kafka"
        eventBus -> personnelService    "PatrolCompleted → historia patroli, EmployeeAccountCreated → inicjalizacja rekordu" "Kafka"

        # Integracje zewnętrzne
        mapGateway     -> mapsApi    "REST/HTTPS"
        weatherGateway -> weatherApi "REST/HTTPS"

        # Bazy danych
        touristAuthService     -> database "schema: tourist_auth" "SQL"
        employeeAuthService    -> database "schema: employee_auth" "SQL"
        personnelService       -> database "schema: personnel (event_store + read)" "SQL"
        areaService            -> database "schema: area (event_store + read)" "SQL"
        tripService            -> database "schema: trips (event_store + read)" "SQL"
        patrolService          -> database "schema: patrols (event_store + read)" "SQL"
        warningService         -> database "schema: warnings (event_store + read)" "SQL"
        notificationService    -> database "schema: notifications" "SQL"
        tripSagaOrchestrator   -> database "schema: saga_state" "SQL"
        patrolSagaOrchestrator -> database "schema: saga_state" "SQL"

        # Cache
        touristAuthService  -> sessionCache     "Sesje JWT turysty"
        employeeAuthService -> sessionCache     "Sesje JWT pracownika"
        tripService         -> readModelCache   "trips_read + aktywne trasy (NF-06)"
        patrolService       -> readModelCache   "patrols_read"
        warningService      -> readModelCache   "warnings_read"
        areaService         -> readModelCache   "areas_read"
        notificationService -> readModelCache   "Odczyt aktywnych tras przy WarningIssued (NF-06)"
        mapGateway          -> integrationCache "Cache tras i danych geograficznych"
        weatherGateway      -> integrationCache "Cache pogody TTL=10min (NF-04)"
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
                background #1d7a4f
                color #ffffff
            }
            element "Software System" {
                shape RoundedBox
                background #1565c0
                color #ffffff
            }
            element "Container" {
                shape RoundedBox
                background #2e7d32
                color #ffffff
            }
            element "Saga" {
                background #6a1b9a
                color #ffffff
            }
            element "Messaging" {
                shape Pipe
                background #e65100
                color #ffffff
            }
            element "Database" {
                shape Cylinder
                background #4e342e
                color #ffffff
            }
            element "Cache" {
                shape Cylinder
                background #558b2f
                color #ffffff
            }
            element "External" {
                background #f57f17
                color #ffffff
            }
        }
    }

    configuration {
        scope softwaresystem
    }
}
