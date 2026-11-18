import React, {useState} from 'react';
import {Button, SafeAreaView, StyleSheet, Text, View} from 'react-native';
import {Angler, AnglerEvent} from '@anglerai/react-native-analytics';

// Dev workspace credentials. Use your own; never commit a real token.
const WORKSPACE_ID = 'example-workspace';
const TOKEN = 'replace-me';

// Configure once at startup. Deep links (including the one that cold-started the app) are
// forwarded automatically through Linking. Fast Refresh re-running this is a no-op.
Angler.configure({
  workspaceId: WORKSPACE_ID,
  token: TOKEN,
  domain: 'dev-data.getangler.ai',
  debugLogging: true,
});

function App(): React.JSX.Element {
  const [status, setStatus] = useState('Ready');
  const run = (label: string, action: () => void) => () => {
    action();
    setStatus(label);
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.buttons}>
        <Button
          title="Track product_viewed"
          onPress={run('Tracked product_viewed', () =>
            Angler.track(AnglerEvent.productViewed, {
              data: {productVariant: {id: 'variant-1', title: 'Example', price: {amount: 29, currencyCode: 'USD'}}},
            }),
          )}
        />
        <Button
          title="Track custom (level_up)"
          onPress={run('Tracked level_up', () => Angler.track('level_up', {properties: {level: '2'}}))}
        />
        <Button title="Flush" onPress={run('Flushing', () => Angler.flush())} />
        <Button title="Reset" onPress={run('Reset', () => Angler.reset())} />
      </View>
      <Text style={styles.status}>{status}</Text>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {flex: 1, justifyContent: 'center'},
  buttons: {gap: 12, paddingHorizontal: 24},
  status: {textAlign: 'center', marginTop: 24},
});

export default App;
