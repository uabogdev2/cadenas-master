<?php

namespace App\Filament\Resources\NotificationResource\Pages;

use App\Filament\Resources\NotificationResource;
use Filament\Resources\Pages\Page;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Filament\Forms;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use App\Services\FirebaseService;
use App\Models\User;

class SendNotification extends Page implements HasForms
{
    use InteractsWithForms;

    protected static string $resource = NotificationResource::class;

    protected static string $view = 'filament.resources.notification-resource.pages.send-notification';

    protected static ?string $title = 'Envoyer une Notification';
    protected static ?string $navigationIcon = 'heroicon-o-paper-airplane';

    public ?array $data = [];

    public function mount(): void
    {
        $this->form->fill();
    }

    public function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\TextInput::make('title')
                    ->label('Titre')
                    ->required(),
                Forms\Components\Textarea::make('body')
                    ->label('Message')
                    ->required(),
                Forms\Components\Select::make('target_type')
                    ->label('Cible')
                    ->options([
                        'topic_all' => 'Tous les joueurs (Topic "all")',
                        'user' => 'Utilisateur spécifique',
                    ])
                    ->reactive()
                    ->default('topic_all'),
                Forms\Components\Select::make('user_id')
                    ->label('Utilisateur')
                    ->options(User::all()->pluck('displayName', 'id'))
                    ->searchable()
                    ->visible(fn (Forms\Get $get) => $get('target_type') === 'user')
                    ->required(fn (Forms\Get $get) => $get('target_type') === 'user'),
            ])
            ->statePath('data');
    }

    public function send(): void
    {
        $data = $this->form->getState();
        $service = new FirebaseService();

        if ($data['target_type'] === 'topic_all') {
            $service->sendNotification($data['title'], $data['body'], null, 'all');
            Notification::make()
                ->title('Envoyé à tous')
                ->success()
                ->send();
        } else {
            $user = User::find($data['user_id']);
            $token = $user->fcmToken;

            if (!$token) {
                Notification::make()
                    ->title('Token introuvable')
                    ->body("L'utilisateur n'a pas de token FCM enregistré.")
                    ->danger()
                    ->send();
                return;
            }

            $service->sendNotification($data['title'], $data['body'], $token);

            Notification::make()
                ->title('Notification envoyée')
                ->success()
                ->send();
        }
    }

    protected function getFormActions(): array
    {
        return [
            Action::make('send')
                ->label('Envoyer')
                ->submit('send'),
        ];
    }
}
