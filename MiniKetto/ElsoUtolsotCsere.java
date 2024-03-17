import java.util.Scanner;

public class ElsoUtolsotCsere {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);


        System.out.println("Add meg a tömb elemeit (szóközzel elválasztva):");
        String input = scanner.nextLine();
        String[] elemek = input.split(" ");


        if (elemek.length < 2) {
            System.out.println("A tömbnek legalább két elemből kell állnia!");
            return;
        }


        String elsoElem = elemek[0];
        elemek[0] = elemek[elemek.length - 1];
        elemek[elemek.length - 1] = elsoElem;


        System.out.println("Az első és az utolsó elem csere után:");
        for (String elem : elemek) {
            System.out.print(elem + " ");
        }

        scanner.close();
    }
}
