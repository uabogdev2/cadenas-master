<?php

namespace App\Filament\Resources;

use App\Filament\Resources\NotificationResource\Pages;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;
use App\Services\FirebaseService;
use Filament\Notifications\Notification as FilamentNotification;

// Création d'un modèle "Faux" pour la ressource, ou utilisation d'un modèle simple de log
// Pour simplifier, on va créer une Page personnalisée dans le système, mais le user a demandé "depuis le tableau de bord".
// Une ressource sans modèle est possible mais complexe.
// On va plutôt créer une Page Filament autonome.

class NotificationResource extends Resource
{
    // On utilise un modèle fictif ou null si possible, mais Filament aime les modèles.
    // On va utiliser une page simple à la place.
    protected static ?string $model = null;
    protected static ?string $navigationLabel = 'Notifications Push';
    protected static ?string $navigationIcon = 'heroicon-o-megaphone';
    protected static ?string $slug = 'notifications';

    public static function getPages(): array
    {
        return [
            'index' => Pages\SendNotification::route('/'),
        ];
    }
}
