<?php

namespace App\Filament\Resources;

use App\Filament\Resources\UserResource\Pages;
use App\Filament\Resources\UserResource\RelationManagers\BattlesRelationManager;
use App\Filament\Resources\UserResource\RelationManagers\ProgressRelationManager;
use App\Filament\Resources\UserResource\RelationManagers\StatsRelationManager;
use App\Filament\Resources\UserResource\RelationManagers\UnlockedHintsRelationManager;
use App\Models\User;
use App\Services\UserService;
use Filament\Actions\Action;
use Filament\Forms;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Filament\Schemas\Schema;
use BackedEnum;
use UnitEnum;

class UserResource extends Resource
{
    protected static ?string $model = User::class;

    protected static BackedEnum|string|null $navigationIcon = 'heroicon-o-user-group';

    protected static ?string $navigationLabel = 'Utilisateurs';

    protected static UnitEnum|string|null $navigationGroup = 'Utilisateurs';

    public static function form(Schema $schema): Schema
    {
        return $schema
            ->schema([
                Forms\Components\TextInput::make('id')
                    ->label('UID')
                    ->disabled(),
                Forms\Components\TextInput::make('displayName')
                    ->required()
                    ->maxLength(191),
                Forms\Components\TextInput::make('email')
                    ->email()
                    ->maxLength(191),
                Forms\Components\TextInput::make('photoURL')
                    ->label('Photo URL')
                    ->maxLength(191),
                Forms\Components\Toggle::make('isAnonymous')
                    ->label('Anonyme'),
                Forms\Components\TextInput::make('points')
                    ->numeric()
                    ->minValue(0),
                Forms\Components\TextInput::make('completedLevels')
                    ->numeric()
                    ->minValue(0),
                Forms\Components\TextInput::make('trophies')
                    ->numeric()
                    ->minValue(0),
            ])
            ->columns(2);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('displayName')
                    ->label('Nom')
                    ->searchable(),
                TextColumn::make('email')
                    ->searchable()
                    ->toggleable(),
                TextColumn::make('points')
                    ->sortable(),
                TextColumn::make('trophies')
                    ->sortable(),
                TextColumn::make('completedLevels')
                    ->label('Niveaux complétés')
                    ->sortable(),
                TextColumn::make('createdAt')
                    ->label('Créé le')
                    ->dateTime()
                    ->sortable(),
            ])
            ->filters([
                TernaryFilter::make('isAnonymous')
                    ->label('Anonyme'),
            ])
            ->actions([
                self::viewUserAction(),
                self::editUserAction(),
                self::adjustPointsAction(),
                self::adjustTrophiesAction(),
                self::resetUserAction(),
            ])
            ->bulkActions([])
            ->defaultSort('createdAt', 'desc');
    }

    public static function getRelations(): array
    {
        return [
            StatsRelationManager::class,
            ProgressRelationManager::class,
            UnlockedHintsRelationManager::class,
            BattlesRelationManager::class,
        ];
    }

    protected static function viewUserAction(): Action
    {
        return Action::make('view')
            ->label('Voir')
            ->icon('heroicon-o-eye')
            ->url(fn (User $record) => static::getUrl('view', ['record' => $record]))
            ->visible(fn () => auth()->user()?->canManageUsers() ?? false);
    }

    protected static function editUserAction(): Action
    {
        return Action::make('edit')
            ->label('Modifier')
            ->icon('heroicon-o-pencil-square')
            ->color('primary')
            ->url(fn (User $record) => static::getUrl('edit', ['record' => $record]))
            ->visible(fn () => auth()->user()?->canManageUsers() ?? false);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListUsers::route('/'),
            'view' => Pages\ViewUser::route('/{record}'),
            'edit' => Pages\EditUser::route('/{record}/edit'),
        ];
    }

    protected static function adjustPointsAction(): Action
    {
        return Action::make('adjustPoints')
            ->label('Ajuster points')
            ->icon('heroicon-o-adjustments-horizontal')
            ->requiresConfirmation()
            ->form([
                Forms\Components\TextInput::make('amount')
                    ->label('Delta')
                    ->numeric()
                    ->required()
                    ->default(0),
                Forms\Components\Textarea::make('reason')
                    ->label('Commentaire')
                    ->rows(2),
            ])
            ->action(function (User $record, array $data, UserService $userService) {
                $userService->adjustPoints($record, (int) $data['amount']);

                Notification::make()
                    ->title('Points mis à jour')
                    ->body("Nouveau total : {$record->points}")
                    ->success()
                    ->send();
            })
            ->visible(fn () => auth()->user()?->canManageUsers());
    }

    protected static function adjustTrophiesAction(): Action
    {
        return Action::make('adjustTrophies')
            ->label('Ajuster trophées')
            ->icon('heroicon-o-trophy')
            ->color('warning')
            ->requiresConfirmation()
            ->form([
                Forms\Components\TextInput::make('amount')
                    ->label('Delta')
                    ->numeric()
                    ->required()
                    ->default(0),
                Forms\Components\Textarea::make('reason')
                    ->label('Commentaire')
                    ->rows(2),
            ])
            ->action(function (User $record, array $data, UserService $userService) {
                $userService->adjustTrophies($record, (int) $data['amount']);

                Notification::make()
                    ->title('Trophées mis à jour')
                    ->body("Nouveau total : {$record->trophies}")
                    ->success()
                    ->send();
            })
            ->visible(fn () => auth()->user()?->canManageUsers());
    }

    protected static function resetUserAction(): Action
    {
        return Action::make('resetUser')
            ->label('Reset utilisateur')
            ->icon('heroicon-o-arrow-path')
            ->color('danger')
            ->requiresConfirmation()
            ->action(function (User $record, UserService $userService) {
                $userService->resetUser($record);

                Notification::make()
                    ->title('Utilisateur réinitialisé')
                    ->body('Progressions et indices supprimés.')
                    ->success()
                    ->send();
            })
            ->visible(fn () => auth()->user()?->canManageUsers());
    }

    public static function canViewAny(): bool
    {
        return auth()->user()?->canManageUsers() ?? false;
    }

    public static function shouldRegisterNavigation(): bool
    {
        return self::canViewAny();
    }
}

