### REJESTRACJA 

#### Rejestracja turysty
Użytkownik rejestruje się w aplikacji webowej. Żądanie trafia przez Public API Gateway do serwisu uwierzytelniania turystów (Tourist Auth Service). Serwis tworzy konto w stanie PENDING, generuje jednorazowy token aktywacyjny oraz publikuje zdarzenie `TouristRegistered`. Serwis powiadomień (Notification Service) konsumuje to zdarzenie, wysyła użytkownikowi link aktywacyjny oraz zapisuje podstawowe dane kontaktowe na potrzeby przyszłej komunikacji. Po kliknięciu linku aktywacyjnego żądanie ponownie trafia do Tourist Auth Service, gdzie token jest weryfikowany (istnienie, jednorazowość, brak użycia). W przypadku poprawnej walidacji konto zostaje oznaczone jako ACTIVE, a token jako wykorzystany. Czas aktywacji konta nie jest ograniczony.

#### Rejestracja pracownika
Przełożony tworzy profil pracownika w aplikacji webowej. Żądanie trafia przez Internal API Gateway do Employee Service, gdzie zapisywane są dane pracownika. Serwis publikuje zdarzenie `EmployeeProfileCreated`. Zdarzenie to jest konsumowane przez Employee Auth Service, który tworzy konto w stanie PENDING oraz generuje token aktywacyjny ważny 24 godziny. Następnie publikowane jest zdarzenie `EmployeeActivationTokenCreated`, które Notification Service wykorzystuje do wysłania zaproszenia (link aktywacyjny) oraz zapisania danych kontaktowych pracownika. Po kliknięciu linku aktywacyjnego użytkownik trafia do Employee Auth Service, gdzie token jest weryfikowany, pracownik ustawia hasło, a konto przechodzi w stan ACTIVE. W konsekwencji publikowane jest zdarzenie `EmployeeAccountActivated`, które Employee Service wykorzystuje do synchronizacji statusu pracownika. Jeśli token nie zostanie wykorzystany w ciągu 24 godzin, mechanizm wygaszania realizowany przez Scheduler wewnątrz Employee Auth Service uruchamia periodyczny proces sprawdzający tabelę tokenów i wygaszający te, które przekroczyły termin ważności. W takim przypadku publikowane jest zdarzenie `EmployeeActivationExpired`, odbierane przez Employee Service, a konto przechodzi w stan EXPIRED. Dane pracownika nie są usuwane — stosowana jest kompensacja polegająca na zmianie statusu konta. Proces może zostać wznowiony poprzez ponowne wygenerowanie tokenu i wysłanie zaproszenia, co skutkuje ponowną publikacją zdarzenia `EmployeeActivationTokenCreated`.


### OBSZARY I PRZYPISANIA 

#### Tworzenie obszaru
Pracownik, korzystając z aplikacji webowej oraz danych dostarczanych przez Map Gateway, definiuje geometrię obszaru i uzupełnia jego dane. Żądanie trafia do Area Service, który przeprowadza walidację - w szczególności sprawdza, czy tworzony podobszar mieści się w granicach obszaru przypisanego do pracownika. Jeśli walidacja zakończy się powodzeniem, obszar zostaje zapisany, a system publikuje zdarzenie `AreaCreated`. Zdarzenie jest konsumowane przez Patrol Service, który zapisuje dane obszaru we własnym modelu w celu późniejszej walidacji tras patroli.

#### Usuwanie obszaru
Przełożony inicjuje usunięcie obszaru w aplikacji webowej. Żądanie trafia do Area Service, który zmienia status obszaru na DELETED i publikuje zdarzenie `AreaDeleted` zawierające identyfikator obszaru. Patrol Service konsumuje zdarzenie i przeprowadza miękkie usunięcie wszystkich patroli powiązanych z tym obszarem — rekordy ze statusem APPROVED lub PENDING_VALIDATION przechodzą w stan CANCELLED. Assignment Service konsumuje zdarzenie i przeprowadza miękkie usunięcie wszystkich przypisań do tego obszaru — rekordy ze statusem ACCEPTED lub PENDING przechodzą w stan CANCELLED. 

#### Przypisywanie pracownika do obszaru 
Przełożony wybiera pracownika w aplikacji webowej, korzystając z danych udostępnianych przez Employee Service oraz informacji o obszarach z Area Service. Następnie tworzy przypisanie w Assignment Service. Rekord przypisania powstaje w stanie PENDING, a system publikuje zdarzenie `AssignmentCreated`. Zdarzenie jest konsumowane przez Notification Service, który wysyła pracownikowi powiadomienie z możliwością akceptacji lub odrzucenia przypisania. Jeśli pracownik zaakceptuje przypisanie, jego status zmienia się na ACCEPTED, a Assignment Service publikuje zdarzenie `AssignmentAccepted`. Jeśli pracownik odrzuci przypisanie, status zmienia się na REJECTED, a Assignment Service publikuje zdarzenie `AssignmentRejected`. Zdarzenia te konsumuje Notification Service, który informuje przełożonego o decyzji pracownika. Odrzucenie traktowane jest jako kompensacja — powiązanie nie obowiązuje, bez fizycznego usuwania danych. Jeśli pracownik nie podejmie decyzji, po 24 godzinach Assignment Service publikuje zdarzenie `AssignmentReminderSent`, a Notification Service wysyła przypomnienie do pracownika. Po upływie 48 godzin, jeśli przypisanie nadal ma status PENDING, Assignment Service automatycznie je akceptuje (ACCEPTED) i publikuje zdarzenie `AssignmentAutoAccepted`. Konsumuje je Notification Service, który wysyła wiadomość do pracownika i przełożonego.

#### Usuwanie pracownika
Przełożony inicjuje usunięcie pracownika w aplikacji webowej. Żądanie trafia do Employee Service, który zmienia status pracownika na DELETED i publikuje zdarzenie `EmployeeAccountDeleted` zawierające identyfikator pracownika. Patrol Service konsumuje zdarzenie i przeprowadza miękkie usunięcie pracownika ze wszystkich przyszłych patroli — jeśli patrol miał więcej uczestników, pracownik jest z niego usuwany, natomiast jeśli był jedynym uczestnikiem, patrol przechodzi w stan CANCELLED. Assignment Service konsumuje zdarzenie i przeprowadza miękkie usunięcie wszystkich przypisań pracownika — rekordy ze statusem ACCEPTED lub PENDING przechodzą w stan CANCELLED. Employee Auth Service konsumuje zdarzenie i blokuje pracownikowi możliwość logowania.


### PATROLE I OSTRZEŻENIA 

#### Wyznaczanie patrolu
Leśniczy tworzy patrol w aplikacji webowej, wskazując uczestników i okienko czasowe. Żądanie trafia przez Internal API Gateway do Patrol Service, który tworzy rekord patrolu ze statusem PENDING_VALIDATION. Patrol Service przeprowadza najpierw walidację trasy lokalnie, korzystając z własnej kopii danych obszarów zbudowanej na podstawie wcześniej skonsumowanych zdarzeń `AreaCreated`. Jeśli trasa wykracza poza granice obszaru, patrol jest natychmiast odrzucany — status zmienia się na REJECTED i nie są podejmowane żadne dalsze kroki. Jeśli walidacja trasy przebiegnie pomyślnie, Patrol Service publikuje zdarzenie `PatrolAssignmentValidationRequested`, zawierające identyfikatory uczestników oraz obszaru. Assignment Service konsumuje to zdarzenie, sprawdza czy każdy uczestnik ma aktywne przypisanie do danego obszaru, po czym publikuje zdarzenie `PatrolAssignmentValidated` lub `PatrolAssignmentRejected`. Patrol Service konsumuje odpowiedź Assignment Service. W przypadku odrzucenia zmienia status patrolu na REJECTED. W przypadku pozytywnej walidacji zatwierdza patrol, zmienia status na APPROVED, zapisuje finalną trasę i publikuje zdarzenie `PatrolCreated`, które Notification Service wykorzystuje do wysłania powiadomień do uczestników.

#### Odbywanie patrolu
Pracownik loguje się do aplikacji webowej i widzi listę patroli przypisanych do siebie. Patrol Service udostępnia do rozpoczęcia tylko te patrole, których okienko czasowe jest aktualnie aktywne. Gdy pracownik rozpoczyna patrol, Patrol Service zmienia status rekordu na ONGOING. Po zakończeniu patrolu pracownik jawnie go zamyka, a Patrol Service zmienia status na COMPLETED.

#### Zgłaszanie ostrzeżenia
W trakcie patrolu pracownik może zgłosić ostrzeżenie poprzez aplikację webową. Żądanie trafia przez Internal API Gateway bezpośrednio do Warning Service, który tworzy pełny rekord incydentu, po czym nadaje mu status ACTIVE. Warning Service publikuje zdarzenie `WarningCreated`. Zdarzenie jest konsumowane przez dwa serwisy, z których każdy realizuje własną logikę powiadamiania. Patrol Service konsumuje zdarzenie i identyfikuje wszystkich pracowników aktualnie odbywających patrole w tym samym obszarze, po czym publikuje zdarzenie `PatrolWarningNotificationRequired` zawierające listę ich identyfikatorów. Trip Service konsumuje zdarzenie `WarningCreated` i identyfikuje wszystkich turystów z aktywną lub zaplanowaną wycieczką w danym obszarze, po czym publikuje zdarzenie `TripWarningNotificationRequired` zawierające listę ich identyfikatorów. Notification Service konsumuje oba zdarzenia i rozsyła powiadomienia do wskazanych odbiorców.

#### Wygasanie ostrzeżeń
Każde ostrzeżenie posiada datę ważności nadawaną automatycznie przy tworzeniu. Wewnętrzny scheduler Warning Service okresowo sprawdza rekordy ze statusem ACTIVE i wygasza te, których data ważności minęła, zmieniając ich status na EXPIRED.


### WYCIECZKI 

#### Wyznaczanie trasy
Trasa wyznaczana jest punkt po punkcie przez Map Gateway, który dostarcza dane geolokalizacyjne. Rekord wycieczki tworzony jest od razu po zdefiniowaniu pierwszego punktu — ze statusem DRAFT. Każde dodanie, usunięcie lub przesunięcie punktu trasy to operacja PATCH na istniejącym rekordzie w Trip Service. Nie ma potrzeby tworzenia osobnych zdarzeń dla każdej zmiany trasy na tym etapie — aktualizacje w trybie DRAFT to lokalne operacje Trip Service, zapisywane bezpośrednio do bazy. Rekord przechodzi w status ACTIVE dopiero gdy organizator jawnie potwierdzi wycieczkę (np. akcja "Opublikuj").

#### Zapraszanie uczestników
Organizator wpisuje maile turystów w aplikacji. Trip Service publikuje zdarzenie `ParticipantInvited` zawierające dane wycieczki i adres email. Notification Service konsumuje zdarzenie i wysyła zaproszenie. Zaproszony turysta akceptuje lub odrzuca zaproszenie — obie akcje trafiają przez Public API Gateway do Trip Service, który aktualizuje lokalny stan uczestnika (ACCEPTED/REJECTED). Brak odpowiedzi nie zmienia stanu systemu, więc nie jest potrzebny żaden mechanizm timeout.

#### Modyfikacje wycieczki
Do momentu rozpoczęcia wycieczki organizator może swobodnie modyfikować trasę, termin i listę uczestników. Wszystkie zmiany to operacje bezpośrednio na rekordzie Trip Service. 

#### Opuszczanie wycieczki
Uczestnik niebędący organizatorem może opuścić wycieczkę w dowolnym momencie — Trip Service usuwa go z listy uczestników. Organizator, aby opuścić wycieczkę, musi najpierw wskazać nowego organizatora spośród uczestników ze statusem ACCEPTED. Trip Service atomowo przenosi rolę i usuwa poprzedniego organizatora z listy. Publikuje zdarzenie `TripOrganizerAssigned`, które Notification Service wykorzystuje do powiadomienia nowego organizatora o zmianie roli. Jeśli organizator był jedynym uczestnikiem, Trip Service usuwa rekord wycieczki bez publikowania zdarzeń.

#### Anulowanie wycieczki
Organizator anuluje wycieczkę jawną akcją. Trip Service zmienia status rekordu na CANCELLED i publikuje zdarzenie `TripCancelled` zawierające listę uczestników. Notification Service konsumuje zdarzenie i rozsyła powiadomienia do wszystkich uczestników. Po anulowaniu wycieczka jest zamknięta — żadne modyfikacje nie są możliwe.

#### Zakończenie wycieczki
W momencie rozpoczęcia wycieczki — czyli nadejścia zdefiniowanego terminu — Trip Service, za pomocą wewnętrznego schedulera, zmienia status rekordu na ONGOING. Uczestnicy realizują wycieczkę poza systemem, system nie śledzi postępu w czasie rzeczywistym. Po upływie terminu zakończenia scheduler zmienia status wycieczki na COMPLETED. 
