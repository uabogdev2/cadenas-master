<?php

namespace App\Filament\Resources;

use App\Filament\Resources\AdminResource\Pages;
use App\Models\Admin;
use App\Models\User;
use Filament\Forms;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Actions\Action;
use Filament\Forms\Components\Section;
use Filament\Tables;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use BackedEnum;
use Filament\Schemas\Schema;
use UnitEnum;

class AdminResource extends Resource
{
    protected static ?string $model = Admin::class;

    protected static BackedEnum|string|null $navigationIcon = 'heroicon-o-shield-check';

    protected static UnitEnum|string|null $navigationGroup = 'Sécurité';

    protected static ?string $navigationLabel = 'Admins';

    public static function form(Schema $schema): Schema
    {
        return $schema
            ->schema([
                Forms\Components\Select::make('userId')
                    ->label('Utilisateur')
                    ->relationship('user', 'displayName', fn (Builder $query) => $query->orderBy('displayName'))
                    ->searchable()
                    ->required()
                    ->unique(ignoreRecord: true)
                    ->disabled(fn (?Admin $record) => $record !== null),
                Forms\Components\Toggle::make('isAdmin')
                    ->label('Actif')
                    ->default(true),
                Section::make('Permissions')
                    ->schema([
                        Forms\Components\Toggle::make('permissions.manageUsers')->label('Gérer utilisateurs'),
                        Forms\Components\Toggle::make('permissions.manageLevels')->label('Gérer niveaux'),
                        Forms\Components\Toggle::make('permissions.manageBattles')->label('Gérer batailles'),
                        Forms\Components\Toggle::make('permissions.viewStats')->label('Voir stats'),
                        Forms\Components\Toggle::make('permissions.manageAdmins')->label('Gérer admins'),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('userId')
                    ->label('UID')
                    ->searchable(),
                TextColumn::make('user.displayName')
                    ->label('Nom'),
                IconColumn::make('permissions.manageUsers')->label('Users')->boolean(),
                IconColumn::make('permissions.manageLevels')->label('Levels')->boolean(),
                IconColumn::make('permissions.manageBattles')->label('Battles')->boolean(),
                IconColumn::make('permissions.viewStats')->label('Stats')->boolean(),
                IconColumn::make('permissions.manageAdmins')->label('Admins')->boolean(),
            ])
            ->filters([])
            ->actions([
                self::editAdminAction(),
                self::deleteAdminAction(),
                Action::make('grantManageAdmins')
                    ->label('Autoriser manageAdmins')
                    ->requiresConfirmation()
                    ->visible(fn (Admin $record) => auth()->user()?->canManageAdmins() && ! ($record->permissions['manageAdmins'] ?? false))
                    ->action(function (Admin $record) {
                        if (! self::canGrantManageAdmins()) {
                            Notification::make()->title('Impossible de déléguer')->body('Au moins deux admins doivent exister pour déléguer.')->danger()->send();

                            return;
                        }

                        $record->permissions = array_merge($record->permissions ?? [], ['manageAdmins' => true]);
                        $record->save();

                        Notification::make()->title('Permission accordée')->success()->send();
                    }),
            ])
            ->bulkActions([]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListAdmins::route('/'),
            'create' => Pages\CreateAdmin::route('/create'),
            'edit' => Pages\EditAdmin::route('/{record}/edit'),
        ];
    }

    public static function canViewAny(): bool
    {
        return auth()->user()?->canManageAdmins() ?? false;
    }

    public static function shouldRegisterNavigation(): bool
    {
        return self::canViewAny();
    }

    protected static function canGrantManageAdmins(): bool
    {
        $count = Admin::query()
            ->where('permissions->manageAdmins', true)
            ->count();

        return $count === 1;
    }

    public static function permissionKeys(): array
    {
        return [
            'manageUsers',
            'manageLevels',
            'manageBattles',
            'viewStats',
            'manageAdmins',
        ];
    }

    public static function normalizePermissions(array $data): array
    {
        $permissions = [];

        foreach (self::permissionKeys() as $key) {
            $permissions[$key] = (bool) data_get($data, "permissions.{$key}", false);
        }

        $data['permissions'] = $permissions;

        if (! ($data['isAdmin'] ?? true)) {
            $data['permissions'] = array_map(fn () => false, $permissions);
        }

        return $data;
    }

    protected static function editAdminAction(): Action
    {
        return Action::make('edit')
            ->label('Modifier')
            ->icon('heroicon-o-pencil-square')
            ->color('primary')
            ->url(fn (Admin $record) => static::getUrl('edit', ['record' => $record]))
            ->visible(fn () => auth()->user()?->canManageAdmins() ?? false);
    }

    protected static function deleteAdminAction(): Action
    {
        return Action::make('delete')
            ->label('Supprimer')
            ->icon('heroicon-o-trash')
            ->color('danger')
            ->requiresConfirmation()
            ->action(fn (Admin $record) => $record->delete())
            ->visible(fn () => auth()->user()?->canManageAdmins() ?? false);
    }
}

