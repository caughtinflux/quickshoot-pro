%ctor
{
	%init;
	[[NSBundle bundleWithIdentifier:@"com.apple.PhotoLibrary"] load];
}
